# -*- coding: utf-8 -*-
"""Import compressed food images from the sibling fitai_win export.

The Windows-friendly export stores photos as short numeric JPEG filenames and
maps them back to product slugs in photo_map.json. This script writes local app
assets as <slug>.webp so SQLite can reference stable asset paths.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FOODS_JSON = ROOT / "assets" / "foods.json"
DEFAULT_SOURCE_DIR = ROOT.parent / "fitai_win" / "photos"
DEFAULT_PHOTO_MAP = ROOT.parent / "fitai_win" / "photo_map.json"
DEFAULT_TARGET_DIR = ROOT / "assets" / "foods" / "images"
IMAGE_EXTENSIONS = {".jpeg", ".jpg", ".png", ".webp"}


def format_size(num_bytes: int) -> str:
    return f"{num_bytes / 1024 / 1024:.2f} MB"


def load_slugs(path: Path) -> list[str]:
    foods = json.loads(path.read_text(encoding="utf-8"))
    slugs: list[str] = []
    seen: set[str] = set()
    duplicates: list[str] = []
    for item in foods:
        slug = str(item.get("slug") or "").strip()
        if not slug:
            continue
        if slug in seen:
            duplicates.append(slug)
            continue
        seen.add(slug)
        slugs.append(slug)
    if duplicates:
        raise ValueError(f"Duplicate slugs in {path}: {', '.join(sorted(duplicates))}")
    return slugs


def load_photo_map(path: Path) -> dict[str, str]:
    rows = json.loads(path.read_text(encoding="utf-8"))
    mapping: dict[str, str] = {}
    duplicate_slugs: list[str] = []
    duplicate_files: list[str] = []
    seen_files: set[str] = set()
    for row in rows:
        slug = str(row.get("slug") or "").strip()
        photo_file = str(row.get("photo_file") or "").strip()
        if not slug or not photo_file:
            continue
        if slug in mapping:
            duplicate_slugs.append(slug)
            continue
        if photo_file in seen_files:
            duplicate_files.append(photo_file)
            continue
        mapping[slug] = photo_file
        seen_files.add(photo_file)
    if duplicate_slugs:
        raise ValueError(
            f"Duplicate slugs in {path}: {', '.join(sorted(duplicate_slugs))}"
        )
    if duplicate_files:
        raise ValueError(
            f"Duplicate photo files in {path}: {', '.join(sorted(duplicate_files))}"
        )
    return mapping


def index_source_images(source_dir: Path) -> dict[str, Path]:
    images: dict[str, Path] = {}
    duplicates: list[str] = []
    for path in sorted(source_dir.iterdir()):
        if not path.is_file() or path.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        if path.stem in images:
            duplicates.append(path.stem)
            continue
        images[path.stem] = path
    if duplicates:
        raise ValueError(
            f"Duplicate source image stems in {source_dir}: "
            f"{', '.join(sorted(duplicates))}"
        )
    return images


def resolve_source_images(
    slugs: list[str],
    source_dir: Path,
    photo_map_path: Path | None,
) -> dict[str, Path]:
    if photo_map_path is not None and photo_map_path.exists():
        photo_map = load_photo_map(photo_map_path)
        missing_map = [slug for slug in slugs if slug not in photo_map]
        if missing_map:
            preview = ", ".join(missing_map[:20])
            suffix = "..." if len(missing_map) > 20 else ""
            raise FileNotFoundError(
                f"Missing {len(missing_map)} photo_map rows for app slugs: "
                f"{preview}{suffix}"
            )

        by_name = {
            path.name: path
            for path in source_dir.iterdir()
            if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
        }
        resolved = {slug: by_name.get(photo_map[slug]) for slug in slugs}
        missing_files = [slug for slug, path in resolved.items() if path is None]
        if missing_files:
            preview = ", ".join(
                f"{slug}->{photo_map[slug]}" for slug in missing_files[:20]
            )
            suffix = "..." if len(missing_files) > 20 else ""
            raise FileNotFoundError(
                f"Missing {len(missing_files)} source image files: "
                f"{preview}{suffix}"
            )
        return {slug: path for slug, path in resolved.items() if path is not None}

    source_images = index_source_images(source_dir)
    missing = [slug for slug in slugs if slug not in source_images]
    if missing:
        preview = ", ".join(missing[:20])
        suffix = "..." if len(missing) > 20 else ""
        raise FileNotFoundError(
            f"Missing {len(missing)} source images for app slugs: {preview}{suffix}"
        )
    return {slug: source_images[slug] for slug in slugs}


def convert_image(source: Path, target: Path, max_side: int, quality: int) -> int:
    with Image.open(source) as image:
        image = ImageOps.exif_transpose(image)
        if image.mode not in ("RGB", "RGBA"):
            image = image.convert("RGB")
        if image.mode == "RGBA":
            background = Image.new("RGB", image.size, (255, 255, 255))
            background.paste(image, mask=image.getchannel("A"))
            image = background
        if max(image.size) > max_side:
            image.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)

        target.parent.mkdir(parents=True, exist_ok=True)
        tmp_target = target.with_name(f"{target.name}.tmp")
        image.save(
            tmp_target,
            format="WEBP",
            quality=quality,
            method=6,
            optimize=True,
        )
        tmp_target.replace(target)
    return target.stat().st_size


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--foods-json", type=Path, default=DEFAULT_FOODS_JSON)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--photo-map", type=Path, default=DEFAULT_PHOTO_MAP)
    parser.add_argument("--target-dir", type=Path, default=DEFAULT_TARGET_DIR)
    parser.add_argument("--max-side", type=int, default=1024)
    parser.add_argument("--quality", type=int, default=70)
    parser.add_argument(
        "--delete-stale",
        action="store_true",
        help="Delete target .webp files whose stem is not present in foods.json.",
    )
    args = parser.parse_args()

    if args.max_side < 64:
        parser.error("--max-side must be at least 64")
    if not 1 <= args.quality <= 100:
        parser.error("--quality must be between 1 and 100")
    if not args.source_dir.exists():
        parser.error(f"Source image directory does not exist: {args.source_dir}")

    slugs = load_slugs(args.foods_json)
    source_images = resolve_source_images(slugs, args.source_dir, args.photo_map)

    source_total = sum(source_images[slug].stat().st_size for slug in slugs)
    target_total = 0
    converted = 0
    for slug in slugs:
        target_total += convert_image(
            source_images[slug],
            args.target_dir / f"{slug}.webp",
            args.max_side,
            args.quality,
        )
        converted += 1
        if converted % 100 == 0:
            print(f"Converted {converted}/{len(slugs)} images")

    deleted = 0
    if args.delete_stale:
        expected = {f"{slug}.webp" for slug in slugs}
        for target in args.target_dir.glob("*.webp"):
            if target.name not in expected:
                target.unlink()
                deleted += 1

    print(
        "Imported "
        f"{converted} images: {format_size(source_total)} -> {format_size(target_total)} "
        f"(max_side={args.max_side}, quality={args.quality})"
    )
    if deleted:
        print(f"Deleted {deleted} stale target images")
    return 0


if __name__ == "__main__":
    sys.exit(main())
