#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import a reviewed, rights-cleared source pack into the canonical catalog.

Usage:
 python3 scripts/import_curated.py database/source-pack.example.json --check
 python3 scripts/import_curated.py path/to/reviewed.json --write
Only accepted source pack records are merged. Does not scrape external websites.
"""
import argparse
import copy
import json
import sys
from pathlib import Path

from build_catalog import INPUT, validate

ALLOWED_LICENSES = {"CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0", "GPL-3.0-or-later", "original"}
TARGET_BUILD = "1.60.1.70888"


def import_pack(current, pack):
    updated = copy.deepcopy(current)
    meta = pack.get("meta", {})
    if meta.get("build") != TARGET_BUILD:
        raise ValueError("Source pack must target " + TARGET_BUILD)
    if meta.get("license") not in ALLOWED_LICENSES:
        raise ValueError("Source license missing, unsupported or unverified")
    if not isinstance(meta.get("sourceUrl"), str) or not meta["sourceUrl"].startswith("https://"):
        raise ValueError("HTTPS source reference required")
    if not isinstance(meta.get("reviewed"), bool) or not meta["reviewed"]:
        raise ValueError("Source pack requires explicit human review")
    for key in ("entities", "recipes"):
        if not isinstance(pack.get(key), list):
            raise ValueError("Source pack missing list: " + key)
    entity_keys = {(e["type"], e["id"]) for e in updated["entities"]}
    for item in pack["entities"]:
        key = (item.get("type"), item.get("id"))
        if key in entity_keys:
            raise ValueError("Duplicate entity already in catalog: %s" % (key,))
        entry = copy.deepcopy(item)
        if not entry.get("provenance"):
            raise ValueError("Entity missing provenance: %s" % (key,))
        updated["entities"].append(entry)
        entity_keys.add(key)
    recipe_ids = {r["spellId"] for r in updated["recipes"]}
    for recipe in pack["recipes"]:
        if recipe.get("spellId") in recipe_ids:
            raise ValueError("Recipe spell already in catalog")
        updated["recipes"].append(copy.deepcopy(recipe))
        recipe_ids.add(recipe["spellId"])
    validate(updated)
    return updated


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("source", type=Path)
    mode = cli.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    args = cli.parse_args()
    base = json.loads(INPUT.read_text(encoding="utf-8"))
    pack = json.loads(args.source.read_text(encoding="utf-8"))
    updated = import_pack(base, pack)
    if args.write:
        INPUT.write_text(json.dumps(updated, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("Imported; regenerate Lua with python3 scripts/build_catalog.py")
    else:
        print("Validated %d new entities and %d new recipes" % (
            len(updated["entities"]) - len(base["entities"]),
            len(updated["recipes"]) - len(base["recipes"])))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as exc:
        print("Import rejected: " + str(exc), file=sys.stderr)
        sys.exit(1)
