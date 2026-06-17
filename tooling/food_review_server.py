#!/usr/bin/env python3
"""Local browser editor for reviewing Eco Fit food names and images."""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import webbrowser
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote, unquote, urlparse


ROOT = Path(__file__).resolve().parent.parent
WEB_ROOT = Path(__file__).resolve().parent / "food_review_web"
DEFAULT_DATA = ROOT / "assets" / "foods.json"
BUILD_SCRIPT = ROOT / "tooling" / "build_offline_db.py"
MAX_REQUEST_BYTES = 16 * 1024 * 1024
IMAGE_MIME_EXTENSIONS = {
    "image/webp": ".webp",
    "image/jpeg": ".jpg",
    "image/png": ".png",
}
NAME_FIELDS = {
    "uz_latn": "name_uz_lat",
    "uz_cyrl": "name_uz_kril",
    "ru": "name_ru",
    "en": "name_en",
}


class ValidationError(ValueError):
    """An error that can be safely shown to the editor user."""


class FoodStore:
    def __init__(self, data_path: Path, rebuild_database: bool = True) -> None:
        self.data_path = data_path.resolve()
        self.rebuild_database = rebuild_database
        self.lock = threading.RLock()
        self._foods: list[dict] = []
        self._mtime_ns = -1
        self._backup_path: Path | None = None
        self._load(force=True)

    def _load(self, force: bool = False) -> None:
        stat = self.data_path.stat()
        if not force and stat.st_mtime_ns == self._mtime_ns:
            return
        loaded = json.loads(self.data_path.read_text(encoding="utf-8"))
        if not isinstance(loaded, list):
            raise RuntimeError(f"Expected a JSON list in {self.data_path}")
        self._foods = loaded
        self._mtime_ns = stat.st_mtime_ns

    @staticmethod
    def _names(item: dict) -> dict[str, str]:
        return {
            "uz_latn": str(item.get("name_uz_lat") or item.get("name_uz") or ""),
            "uz_cyrl": str(
                item.get("name_uz_kril")
                or item.get("name_uz_cyrl")
                or item.get("name_uz_kiril")
                or ""
            ),
            "ru": str(item.get("name_ru") or ""),
            "en": str(item.get("name_en") or ""),
        }

    def _image_path(self, item: dict) -> Path | None:
        candidates = [
            item.get("image_asset_path"),
            item.get("image_asset"),
            item.get("asset_path"),
            item.get("image_path"),
        ]
        slug = str(item.get("slug") or "").strip()
        if slug:
            candidates.extend(
                f"assets/foods/images/{slug}{extension}"
                for extension in (".webp", ".jpg", ".jpeg", ".png")
            )
        for candidate in candidates:
            if not candidate:
                continue
            path = (ROOT / str(candidate).lstrip("/\\")).resolve()
            try:
                path.relative_to(ROOT)
            except ValueError:
                continue
            if path.is_file():
                return path
        return None

    def _summary(self, item: dict, index: int) -> dict:
        image_path = self._image_path(item)
        image_url = None
        if image_path:
            relative = image_path.relative_to(ROOT).as_posix()
            version = image_path.stat().st_mtime_ns
            image_url = f"/media/{quote(relative, safe='/')}?v={version}"
        return {
            "index": index,
            "slug": str(item.get("slug") or ""),
            "category": str(item.get("category") or ""),
            "names": self._names(item),
            "image_url": image_url,
        }

    def list_foods(self) -> list[dict]:
        with self.lock:
            self._load()
            return [self._summary(item, index) for index, item in enumerate(self._foods)]

    def get_food(self, slug: str) -> dict | None:
        with self.lock:
            self._load()
            for index, item in enumerate(self._foods):
                if item.get("slug") == slug:
                    result = self._summary(item, index)
                    result["nutrition"] = item.get("per_100g") or {}
                    return result
        return None

    def _find(self, slug: str) -> tuple[int, dict]:
        for index, item in enumerate(self._foods):
            if item.get("slug") == slug:
                return index, item
        raise KeyError(slug)

    @staticmethod
    def _validated_names(payload: dict) -> dict[str, str]:
        names = payload.get("names")
        if not isinstance(names, dict):
            raise ValidationError("Не переданы названия продукта")
        validated: dict[str, str] = {}
        for locale in NAME_FIELDS:
            value = names.get(locale)
            if not isinstance(value, str):
                raise ValidationError(f"Название {locale} должно быть текстом")
            value = value.strip()
            if not value:
                raise ValidationError(f"Название {locale} не может быть пустым")
            if len(value) > 300:
                raise ValidationError(f"Название {locale} слишком длинное")
            validated[locale] = value
        return validated

    def _write_image(self, slug: str, image: dict) -> str:
        mime = image.get("mime")
        encoded = image.get("base64")
        if mime not in IMAGE_MIME_EXTENSIONS or not isinstance(encoded, str):
            raise ValidationError("Поддерживаются изображения WEBP, JPG и PNG")
        try:
            raw = base64.b64decode(encoded, validate=True)
        except (ValueError, TypeError) as error:
            raise ValidationError("Не удалось прочитать выбранное изображение") from error
        if not raw or len(raw) > 10 * 1024 * 1024:
            raise ValidationError("Размер изображения должен быть от 1 байта до 10 МБ")

        image_dir = ROOT / "assets" / "foods" / "images"
        image_dir.mkdir(parents=True, exist_ok=True)
        destination = image_dir / f"{slug}{IMAGE_MIME_EXTENSIONS[mime]}"
        temp_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="wb", delete=False, dir=image_dir, prefix=f".{slug}.", suffix=".tmp"
            ) as handle:
                temp_path = Path(handle.name)
                handle.write(raw)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temp_path, destination)
        finally:
            if temp_path and temp_path.exists():
                temp_path.unlink()
        return destination.relative_to(ROOT).as_posix()

    def _ensure_backup(self) -> Path:
        if self._backup_path is None:
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            backup_dir = (
                ROOT / "tooling" / ".food_review_backups"
                if self.data_path == DEFAULT_DATA.resolve()
                else self.data_path.parent / ".food_review_backups"
            )
            backup_dir.mkdir(parents=True, exist_ok=True)
            self._backup_path = backup_dir / f"foods-{stamp}.json"
            shutil.copy2(self.data_path, self._backup_path)
        return self._backup_path

    def _write_json_atomically(self) -> None:
        temp_path: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                newline="\n",
                delete=False,
                dir=self.data_path.parent,
                prefix=".foods.",
                suffix=".tmp",
            ) as handle:
                temp_path = Path(handle.name)
                json.dump(self._foods, handle, ensure_ascii=False, indent=2)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temp_path, self.data_path)
            self._mtime_ns = self.data_path.stat().st_mtime_ns
        finally:
            if temp_path and temp_path.exists():
                temp_path.unlink()

    def _rebuild(self) -> tuple[bool, str | None]:
        if not self.rebuild_database:
            return False, "Пересборка SQLite отключена"
        if self.data_path != DEFAULT_DATA.resolve():
            return False, "Тестовый JSON сохранён без пересборки основной SQLite"
        process = subprocess.run(
            [sys.executable, str(BUILD_SCRIPT)],
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=120,
            check=False,
        )
        if process.returncode != 0:
            details = (process.stderr or process.stdout).strip()
            return False, f"JSON сохранён, но SQLite не пересобрана: {details}"
        return True, None

    def update_food(self, slug: str, payload: dict) -> dict:
        with self.lock:
            self._load()
            index, item = self._find(slug)
            names = self._validated_names(payload)
            category = payload.get("category", item.get("category") or "")
            if not isinstance(category, str) or not category.strip():
                raise ValidationError("Категория не может быть пустой")
            if len(category.strip()) > 200:
                raise ValidationError("Название категории слишком длинное")

            self._ensure_backup()
            image = payload.get("image")
            if image is not None:
                if not isinstance(image, dict):
                    raise ValidationError("Некорректные данные изображения")
                old_image = self._image_path(item)
                if old_image:
                    image_backup_dir = self._backup_path.parent / "images"
                    image_backup_dir.mkdir(parents=True, exist_ok=True)
                    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
                    shutil.copy2(
                        old_image,
                        image_backup_dir / f"{slug}-{stamp}{old_image.suffix.lower()}",
                    )
                item["image_asset_path"] = self._write_image(slug, image)

            for locale, field in NAME_FIELDS.items():
                item[field] = names[locale]
            item["category"] = category.strip()
            self._write_json_atomically()
            rebuilt, warning = self._rebuild()
            result = self._summary(item, index)
            try:
                backup_label = self._backup_path.relative_to(ROOT).as_posix()
            except ValueError:
                backup_label = str(self._backup_path)
            result.update(
                {
                    "database_rebuilt": rebuilt,
                    "warning": warning,
                    "backup": backup_label,
                }
            )
            return result

    def delete_food(self, slug: str) -> dict:
        with self.lock:
            self._load()
            index, item = self._find(slug)
            self._ensure_backup()
            deleted = self._foods.pop(index)
            try:
                self._write_json_atomically()
            except Exception:
                self._foods.insert(index, deleted)
                raise
            rebuilt, warning = self._rebuild()
            try:
                backup_label = self._backup_path.relative_to(ROOT).as_posix()
            except ValueError:
                backup_label = str(self._backup_path)
            return {
                "deleted": True,
                "slug": slug,
                "name": self._names(item).get("ru") or self._names(item).get("uz_latn") or slug,
                "database_rebuilt": rebuilt,
                "warning": warning,
                "backup": backup_label,
                "remaining": len(self._foods),
            }


class FoodReviewHandler(BaseHTTPRequestHandler):
    server_version = "EcoFitFoodReview/1.0"

    @property
    def store(self) -> FoodStore:
        return self.server.store  # type: ignore[attr-defined]

    def log_message(self, format: str, *args: object) -> None:
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")

    def _send_bytes(
        self,
        data: bytes,
        content_type: str,
        status: HTTPStatus = HTTPStatus.OK,
        cache_control: str = "no-store",
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", cache_control)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def _send_json(self, payload: object, status: HTTPStatus = HTTPStatus.OK) -> None:
        self._send_bytes(
            json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            "application/json; charset=utf-8",
            status,
        )

    def _send_error_json(self, message: str, status: HTTPStatus) -> None:
        self._send_json({"error": message}, status)

    def _serve_file(self, path: Path, cache_control: str = "no-cache") -> None:
        if not path.is_file():
            self._send_error_json("Файл не найден", HTTPStatus.NOT_FOUND)
            return
        mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        self._send_bytes(path.read_bytes(), mime, cache_control=cache_control)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path
        if path == "/api/health":
            self._send_json({"status": "ok"})
            return
        if path == "/api/foods":
            items = self.store.list_foods()
            self._send_json({"items": items, "total": len(items)})
            return
        if path.startswith("/api/foods/"):
            slug = unquote(path.removeprefix("/api/foods/"))
            item = self.store.get_food(slug)
            if item is None:
                self._send_error_json("Продукт не найден", HTTPStatus.NOT_FOUND)
            else:
                self._send_json(item)
            return
        if path.startswith("/media/"):
            relative = unquote(path.removeprefix("/media/")).lstrip("/\\")
            media_path = (ROOT / relative).resolve()
            try:
                media_path.relative_to(ROOT / "assets" / "foods" / "images")
            except ValueError:
                self._send_error_json("Недопустимый путь", HTTPStatus.FORBIDDEN)
                return
            self._serve_file(media_path, cache_control="public, max-age=31536000, immutable")
            return

        static_files = {
            "/": WEB_ROOT / "index.html",
            "/index.html": WEB_ROOT / "index.html",
            "/app.js": WEB_ROOT / "app.js",
            "/styles.css": WEB_ROOT / "styles.css",
        }
        static_path = static_files.get(path)
        if static_path:
            self._serve_file(static_path)
        else:
            self._send_error_json("Страница не найдена", HTTPStatus.NOT_FOUND)

    def _read_json_body(self) -> dict:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ValidationError("Некорректный размер запроса") from error
        if length <= 0 or length > MAX_REQUEST_BYTES:
            raise ValidationError("Запрос пустой или слишком большой")
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ValidationError("Некорректный JSON") from error
        if not isinstance(payload, dict):
            raise ValidationError("Ожидался JSON-объект")
        return payload

    def do_PUT(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if not path.startswith("/api/foods/"):
            self._send_error_json("Метод не поддерживается", HTTPStatus.NOT_FOUND)
            return
        slug = unquote(path.removeprefix("/api/foods/"))
        try:
            payload = self._read_json_body()
            result = self.store.update_food(slug, payload)
        except KeyError:
            self._send_error_json("Продукт не найден", HTTPStatus.NOT_FOUND)
        except ValidationError as error:
            self._send_error_json(str(error), HTTPStatus.BAD_REQUEST)
        except subprocess.TimeoutExpired:
            self._send_error_json(
                "JSON сохранён, но пересборка SQLite заняла слишком много времени",
                HTTPStatus.INTERNAL_SERVER_ERROR,
            )
        except Exception as error:  # Keep the local editor alive and report the failure.
            self._send_error_json(f"Ошибка сохранения: {error}", HTTPStatus.INTERNAL_SERVER_ERROR)
        else:
            self._send_json(result)

    def do_DELETE(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if not path.startswith("/api/foods/"):
            self._send_error_json("Метод не поддерживается", HTTPStatus.NOT_FOUND)
            return
        slug = unquote(path.removeprefix("/api/foods/"))
        try:
            result = self.store.delete_food(slug)
        except KeyError:
            self._send_error_json("Продукт не найден", HTTPStatus.NOT_FOUND)
        except subprocess.TimeoutExpired:
            self._send_error_json(
                "Продукт удалён из JSON, но пересборка SQLite заняла слишком много времени",
                HTTPStatus.INTERNAL_SERVER_ERROR,
            )
        except Exception as error:
            self._send_error_json(f"Ошибка удаления: {error}", HTTPStatus.INTERNAL_SERVER_ERROR)
        else:
            self._send_json(result)


class FoodReviewServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], store: FoodStore) -> None:
        super().__init__(address, FoodReviewHandler)
        self.store = store


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--no-rebuild", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    store = FoodStore(args.data, rebuild_database=not args.no_rebuild)
    server = FoodReviewServer((args.host, args.port), store)
    url = f"http://{args.host}:{args.port}"
    print(f"Eco Fit food review: {url}")
    print("Press Ctrl+C to stop.")
    if not args.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
