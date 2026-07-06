#!/usr/bin/env python3
"""Local browser editor for reviewing Eco Fit micronutrients (per 100 g).

Sibling of ``food_review_server.py``: that tool edits names/images, this one
edits the nutrition — the four macros plus every micronutrient and vitamin the
offline database knows about. The full nutrient dictionary is imported straight
from ``build_offline_db.py`` so the editor can never drift from the codes, units
and ordering the SQLite build actually understands.

Edits are written back to ``assets/foods.json`` (atomic write + timestamped
backup) and the offline SQLite base is rebuilt, exactly like the food editor.

Usage:
    python tooling/micros_review_server.py
    python tooling/micros_review_server.py --no-rebuild --data /tmp/foods.json
"""

from __future__ import annotations

import argparse
import base64
import json
import math
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
WEB_ROOT = Path(__file__).resolve().parent / "micros_review_web"
DEFAULT_DATA = ROOT / "assets" / "foods.json"
BUILD_SCRIPT = ROOT / "tooling" / "build_offline_db.py"
MAX_REQUEST_BYTES = 16 * 1024 * 1024
IMAGE_MIME_EXTENSIONS = {
    "image/webp": ".webp",
    "image/jpeg": ".jpg",
    "image/png": ".png",
}

# Import the canonical nutrient dictionary so codes/units/order stay in lockstep
# with the SQLite build. build_offline_db.py is import-safe (main() is guarded).
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_offline_db  # noqa: E402

# Macros live at the top level of per_100g under short keys; the offline build
# maps them to these nutrient codes. Order here is the order shown in the editor.
MACRO_MAP = [
    ("kcal", "energy_kcal"),
    ("protein", "protein"),
    ("carbs", "carbs"),
    ("fat", "fat"),
]
MACRO_JSON_KEYS = {json_key for json_key, _ in MACRO_MAP}

UNIT_LABELS = {"kcal": "ккал", "g": "г", "mg": "мг", "mcg": "мкг"}

# Anything above this per-100 g amount is almost certainly a typo (pure table
# salt is ~38 700 mg sodium / 100 g, so the ceiling is deliberately generous).
MAX_AMOUNT = 1_000_000.0

NAME_FIELDS = {
    "uz_latn": "name_uz_lat",
    "uz_cyrl": "name_uz_kril",
    "ru": "name_ru",
    "en": "name_en",
}


def _build_catalog() -> dict:
    """Split the canonical nutrient list into the editor's three sections."""
    by_code = {
        code: {"code": code, "group": group, "unit": unit,
                "unit_label": UNIT_LABELS.get(unit, unit),
                "sort_order": sort_order, "names": translations}
        for code, group, unit, sort_order, translations in build_offline_db.NUTRIENTS
    }
    macros = []
    for json_key, code in MACRO_MAP:
        meta = by_code.get(code)
        if meta is None:
            continue
        macros.append({**meta, "json_key": json_key})
    minerals = sorted(
        (m for m in by_code.values() if m["group"] == "micro"),
        key=lambda m: m["sort_order"],
    )
    vitamins = sorted(
        (m for m in by_code.values() if m["group"] == "vitamin"),
        key=lambda m: m["sort_order"],
    )
    return {"macros": macros, "minerals": minerals, "vitamins": vitamins}


CATALOG = _build_catalog()
# Every micro/vitamin code the editor is allowed to write, in canonical order.
MICRO_CODES = [m["code"] for m in CATALOG["minerals"] + CATALOG["vitamins"]]
MICRO_CODE_SET = set(MICRO_CODES)
MICRO_TOTAL = len(MICRO_CODES)


class ValidationError(ValueError):
    """An error that can be safely shown to the editor user."""


def _clean_amount(raw: object, label: str) -> float | None:
    """Return a non-negative finite float, or None when the field is blank."""
    if raw is None:
        return None
    if isinstance(raw, bool):  # bool is an int subclass — reject explicitly.
        raise ValidationError(f"«{label}»: недопустимое значение")
    if isinstance(raw, str):
        text = raw.strip().replace(",", ".")
        if not text:
            return None
        try:
            value = float(text)
        except ValueError as error:
            raise ValidationError(f"«{label}»: «{raw}» не является числом") from error
    elif isinstance(raw, (int, float)):
        value = float(raw)
    else:
        raise ValidationError(f"«{label}»: недопустимое значение")
    if not math.isfinite(value):
        raise ValidationError(f"«{label}»: значение должно быть конечным числом")
    if value < 0:
        raise ValidationError(f"«{label}»: значение не может быть отрицательным")
    if value > MAX_AMOUNT:
        raise ValidationError(f"«{label}»: слишком большое значение (> {MAX_AMOUNT:.0f})")
    return value


def _tidy_number(value: float) -> float | int:
    """Store whole numbers as ints so the JSON diff stays clean."""
    if float(value).is_integer():
        return int(value)
    return round(value, 6)


class MicroStore:
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

    @staticmethod
    def _micros(item: dict) -> dict[str, float]:
        per = item.get("per_100g") or {}
        micros = per.get("micros") or {}
        return {
            code: value
            for code, value in micros.items()
            if code in MICRO_CODE_SET and isinstance(value, (int, float))
            and not isinstance(value, bool)
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
        per = item.get("per_100g") or {}
        filled = len(self._micros(item))
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
            "emoji": str(item.get("emoji") or ""),
            "type": str(per.get("type") or ""),
            "names": self._names(item),
            "image_url": image_url,
            "filled": filled,
            "total": MICRO_TOTAL,
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
                    per = item.get("per_100g") or {}
                    result = self._summary(item, index)
                    result["macros"] = {
                        json_key: per.get(json_key) for json_key, _ in MACRO_MAP
                    }
                    result["micros"] = self._micros(item)
                    return result
        return None

    def _find(self, slug: str) -> tuple[int, dict]:
        for index, item in enumerate(self._foods):
            if item.get("slug") == slug:
                return index, item
        raise KeyError(slug)

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

    @staticmethod
    def _validated_category(payload: dict, item: dict) -> str:
        category = payload.get("category", item.get("category") or "")
        if not isinstance(category, str) or not category.strip():
            raise ValidationError("Категория не может быть пустой")
        category = category.strip()
        if len(category) > 200:
            raise ValidationError("Название категории слишком длинное")
        return category

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

    def _validated_payload(self, payload: dict) -> tuple[dict[str, float], dict[str, float | None]]:
        macros_in = payload.get("macros")
        if not isinstance(macros_in, dict):
            raise ValidationError("Не переданы макронутриенты")
        macro_labels = {m["json_key"]: m["names"]["ru"] for m in CATALOG["macros"]}
        macros: dict[str, float] = {}
        for json_key in MACRO_JSON_KEYS:
            value = _clean_amount(macros_in.get(json_key), macro_labels.get(json_key, json_key))
            if value is None:
                raise ValidationError(f"«{macro_labels.get(json_key, json_key)}»: обязательное поле")
            macros[json_key] = value

        micros_in = payload.get("micros")
        if not isinstance(micros_in, dict):
            raise ValidationError("Не переданы микронутриенты")
        catalog_labels = {
            m["code"]: m["names"]["ru"] for m in CATALOG["minerals"] + CATALOG["vitamins"]
        }
        micros: dict[str, float | None] = {}
        for code, raw in micros_in.items():
            if code not in MICRO_CODE_SET:
                raise ValidationError(f"Неизвестный код нутриента: {code}")
            micros[code] = _clean_amount(raw, catalog_labels.get(code, code))
        return macros, micros

    def update_food(self, slug: str, payload: dict) -> dict:
        with self.lock:
            self._load()
            index, item = self._find(slug)
            names = self._validated_names(payload)
            category = self._validated_category(payload, item)
            macros, micros = self._validated_payload(payload)

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
            item["category"] = category

            per = item.get("per_100g")
            if not isinstance(per, dict):
                per = {}
                item["per_100g"] = per

            for json_key, value in macros.items():
                per[json_key] = _tidy_number(value)

            existing = per.get("micros") if isinstance(per.get("micros"), dict) else {}
            merged: dict[str, float] = {}
            # Keep any codes we do not manage (should be none) untouched and first.
            for code, value in existing.items():
                if code not in MICRO_CODE_SET:
                    merged[code] = value
            for code in MICRO_CODES:
                if code in micros:
                    value = micros[code]
                    if value is None:
                        continue  # blank field removes the nutrient
                    merged[code] = _tidy_number(value)
                elif code in existing:
                    merged[code] = existing[code]  # not sent → leave as-is
            if merged:
                per["micros"] = merged
            else:
                per.pop("micros", None)

            self._write_json_atomically()
            rebuilt, warning = self._rebuild()
            result = self._summary(item, index)
            result["macros"] = {json_key: per.get(json_key) for json_key, _ in MACRO_MAP}
            result["micros"] = self._micros(item)
            try:
                backup_label = self._backup_path.relative_to(ROOT).as_posix()
            except ValueError:
                backup_label = str(self._backup_path)
            result.update(
                {"database_rebuilt": rebuilt, "warning": warning, "backup": backup_label}
            )
            return result


class MicroReviewHandler(BaseHTTPRequestHandler):
    server_version = "EcoFitMicroReview/1.0"

    @property
    def store(self) -> MicroStore:
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
        path = urlparse(self.path).path
        if path == "/api/health":
            self._send_json({"status": "ok"})
            return
        if path == "/api/catalog":
            self._send_json({"catalog": CATALOG, "total": MICRO_TOTAL})
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


class MicroReviewServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], store: MicroStore) -> None:
        super().__init__(address, MicroReviewHandler)
        self.store = store


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--no-rebuild", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    store = MicroStore(args.data, rebuild_database=not args.no_rebuild)
    server = MicroReviewServer((args.host, args.port), store)
    url = f"http://{args.host}:{args.port}"
    print(f"Eco Fit micronutrient review: {url}")
    print(f"Editing {MICRO_TOTAL} micronutrients per food from {store.data_path}")
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
