# -*- coding: utf-8 -*-
"""Verify the rebuilt offline DB against the rich historical DB.

Checks, after T2 restored the micronutrients that commit ``be0842d`` dropped:

  1. Nutrient-code coverage in ``food_nutrients`` (new vs. old, per code).
  2. Value spot-check for a handful of foods (new vs. old, by slug).
  3. Calorie sanity: ``kcal`` vs. ``4P + 4C + 9F`` (alcohol carries extra
     energy from ethanol at ~7 kcal/g, high-fibre foods read low — both are
     reported, not treated as hard failures).
  4. FTS5 search index is present and populated.
  5. Curated piece servings survived the rebuild.

The old DB is read straight out of git history (default ``8f5e262``) so the
script is self-contained; pass ``--old-db`` to point at an explicit file.

Usage:
    python tooling/verify_micros.py
    python tooling/verify_micros.py --old-ref 8f5e262 --new-db assets/db/eco_fit.db
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_NEW = ROOT / "assets" / "db" / "eco_fit.db"
DEFAULT_FOODS = ROOT / "assets" / "foods.json"
DEFAULT_OLD_REF = "8f5e262"

# Foods whose energy legitimately exceeds 4P+4C+9F because of ethanol
# (~7 kcal/g). Reported but not counted as calorie errors.
ETHANOL_HINTS = (
    "vino", "vinosi", "aroq", "viski", "konyak", "tekila", "rom", "likyor",
    "shampan", "pivo", "martini", "vermut", "mohito", "margarita", "daykiri",
    "krovavaya", "koktey", "absent", "jin_tonik", "muskat",
)

# Spot-check foods spanning fixed errors, restored vitamins and plain minerals.
SPOT_SLUGS = [
    "qoy_beli", "laminariya_dengiz_karami", "achchiq_qalampir",
    "braziliya_yong_og_i", "tovuq_jigari",
]


def load_old_db(old_db: str | None, old_ref: str) -> str:
    if old_db:
        return old_db
    tmp = Path(tempfile.gettempdir()) / f"eco_fit_old_{old_ref}.db"
    blob = subprocess.run(
        ["git", "cat-file", "blob", f"{old_ref}:assets/db/eco_fit.db"],
        cwd=ROOT, capture_output=True, check=True,
    ).stdout
    tmp.write_bytes(blob)
    return str(tmp)


def code_coverage(conn: sqlite3.Connection) -> dict[str, int]:
    rows = conn.execute(
        """
        SELECT n.code, COUNT(*) AS n
        FROM food_nutrients fn
        JOIN nutrients n ON n.id = fn.nutrient_id
        WHERE fn.amount_per_100g IS NOT NULL AND fn.amount_per_100g != 0
        GROUP BY n.code
        """
    ).fetchall()
    return {r[0]: r[1] for r in rows}


def food_micros(conn: sqlite3.Connection, slug: str) -> dict[str, float]:
    rows = conn.execute(
        """
        SELECT n.code, fn.amount_per_100g
        FROM foods f
        JOIN food_nutrients fn ON fn.food_id = f.id
        JOIN nutrients n ON n.id = fn.nutrient_id
        WHERE f.slug = ? AND n.group_code IN ('micro', 'vitamin')
        ORDER BY n.sort_order
        """,
        (slug,),
    ).fetchall()
    return {r[0]: r[1] for r in rows}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--new-db", type=Path, default=DEFAULT_NEW)
    parser.add_argument("--old-db", default=None,
                        help="explicit old DB file (skips git extraction)")
    parser.add_argument("--old-ref", default=DEFAULT_OLD_REF)
    parser.add_argument("--foods", type=Path, default=DEFAULT_FOODS)
    args = parser.parse_args()

    sys.stdout.reconfigure(encoding="utf-8")

    old_path = load_old_db(args.old_db, args.old_ref)
    new = sqlite3.connect(str(args.new_db))
    old = sqlite3.connect(old_path)

    problems: list[str] = []

    # 1) coverage --------------------------------------------------------
    new_cov = code_coverage(new)
    old_cov = code_coverage(old)
    macros = {"energy_kcal", "protein", "carbs", "fat", "fiber", "sugar"}
    micro_codes = sorted(
        set(new_cov) | set(old_cov),
        key=lambda c: -(new_cov.get(c, 0)),
    )
    print("=== 1. Nutrient coverage (foods with non-zero value) ===")
    print(f"{'code':10s} {'new':>6s} {'old':>6s}   delta")
    micro_present = 0
    for code in micro_codes:
        if code in macros:
            continue
        nv, ov = new_cov.get(code, 0), old_cov.get(code, 0)
        if nv > 0:
            micro_present += 1
        flag = ""
        # regression only matters where the food still exists in the new base;
        # allow a small margin for removed dishes.
        if ov > 0 and nv < 0.6 * ov:
            flag = "  <-- LOW vs old"
            problems.append(f"coverage {code}: new={nv} old={ov}")
        print(f"{code:10s} {nv:6d} {ov:6d}   {nv-ov:+5d}{flag}")
    print(f"\nMicro/vitamin codes with data: {micro_present} "
          f"(old had {sum(1 for c,v in old_cov.items() if c not in macros and v)})")
    if micro_present < 30:
        problems.append(f"only {micro_present} micro codes populated (<30)")

    # 2) spot-check ------------------------------------------------------
    print("\n=== 2. Value spot-check (new vs old, per 100 g) ===")
    for slug in SPOT_SLUGS:
        nm = food_micros(new, slug)
        om = food_micros(old, slug)
        if not nm:
            problems.append(f"spot-check: {slug} missing from new DB")
            print(f"  {slug}: MISSING in new DB")
            continue
        diffs = []
        for code in sorted(set(nm) | set(om)):
            nv, ov = nm.get(code), om.get(code)
            mark = "" if nv == ov else f"  (old={ov})"
            if nv is not None and ov is not None and nv != ov:
                diffs.append(code)
            # informative print for a compact subset
        shown = {k: nm[k] for k in list(nm)[:8]}
        print(f"  {slug}: {shown}"
              + (" ..." if len(nm) > 8 else ""))
        if diffs:
            print(f"      differs from old on: {diffs}")

    # 3) calories --------------------------------------------------------
    print("\n=== 3. Calorie sanity (kcal vs 4P+4C+9F) ===")
    rows = new.execute(
        """
        SELECT f.slug, s.kcal_per_100g, s.protein_g_per_100g,
               s.carbs_g_per_100g, s.fat_g_per_100g
        FROM foods f JOIN food_nutrition_summary s ON s.food_id = f.id
        """
    ).fetchall()
    high, low = [], []
    for slug, kcal, p, c, fa in rows:
        p, c, fa = p or 0, c or 0, fa or 0
        calc = 4 * p + 4 * c + 9 * fa
        if kcal is None:
            continue
        if kcal - calc > 40 and kcal - calc > 0.3 * max(kcal, 1):
            high.append((slug, kcal, calc))
        elif calc - kcal > 40 and calc - kcal > 0.3 * max(calc, 1):
            low.append((slug, kcal, calc))
    non_alcohol_high = [x for x in high
                        if not any(h in x[0] for h in ETHANOL_HINTS)]
    print(f"  kcal >> macros: {len(high)} foods "
          f"({len(high)-len(non_alcohol_high)} look alcoholic/ethanol)")
    for slug, kcal, calc in sorted(non_alcohol_high,
                                   key=lambda x: x[2]-x[1])[:10]:
        print(f"     HIGH non-alcohol: {slug} kcal={kcal} calc={calc:.0f}")
    print(f"  kcal << macros: {len(low)} foods "
          f"(high-fibre foods read low here — expected)")
    for slug, kcal, calc in sorted(low, key=lambda x: x[1]-x[2])[:10]:
        print(f"     LOW: {slug} kcal={kcal} calc={calc:.0f}")

    # 4) FTS -------------------------------------------------------------
    print("\n=== 4. FTS5 search index ===")
    try:
        fts_rows = new.execute(
            "SELECT COUNT(*) FROM food_search_fts").fetchone()[0]
        hit = new.execute(
            "SELECT COUNT(*) FROM food_search_fts "
            "WHERE food_search_fts MATCH 'palov'").fetchone()[0]
        flag = new.execute(
            "SELECT value FROM metadata WHERE key='fts5_enabled'").fetchone()
        print(f"  rows={fts_rows}  match('palov')={hit}  fts5_enabled={flag[0] if flag else '?'}")
        if hit == 0:
            problems.append("FTS search returned no hits for a known term")
        if fts_rows == 0:
            problems.append("FTS index empty")
    except sqlite3.DatabaseError as exc:
        problems.append(f"FTS check failed: {exc}")
        print(f"  FTS check failed: {exc}")

    # 5) piece servings --------------------------------------------------
    print("\n=== 5. Curated piece servings ===")
    piece = new.execute(
        """
        SELECT COUNT(DISTINCT fsu.food_id)
        FROM food_serving_units fsu
        JOIN units u ON u.id = fsu.unit_id
        WHERE u.code = 'piece'
        """
    ).fetchone()[0]
    piece_default = new.execute(
        """
        SELECT COUNT(*) FROM foods f
        JOIN units u ON u.id = f.default_unit_id
        WHERE u.code = 'piece'
        """
    ).fetchone()[0]
    print(f"  foods with a piece serving: {piece}  "
          f"(piece as default unit: {piece_default})")
    if piece == 0:
        problems.append("no piece servings found")

    # summary ------------------------------------------------------------
    print("\n=== SUMMARY ===")
    if problems:
        print(f"FAIL — {len(problems)} problem(s):")
        for p in problems:
            print("  -", p)
    else:
        print("PASS — coverage restored, FTS intact, piece servings intact.")

    new.close()
    old.close()
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
