#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate canonical Fishing Atlas data and emit deterministic Lua 5.1 tables."""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "database" / "catalog.json"
OUTPUT = ROOT / "FishingAtlas" / "Data" / "Catalog.lua"
KINDS = {"item", "spell", "npc", "zone", "school", "quest"}
CONFIDENCE = {"reference", "provisional", "verified_client", "verified_ingame", "community"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_source(value, context):
    require(isinstance(value, list) and len(value) > 0, context + ": missing provenance")
    for source in value:
        require(isinstance(source, dict), context + ": malformed provenance")
        require(isinstance(source.get("source"), str) and source["source"], context + ": source required")
        require(isinstance(source.get("build"), str) and source["build"], context + ": build required")
        require(isinstance(source.get("verifiedInForever"), bool), context + ": Forever verification required")
        if "url" in source:
            require(isinstance(source["url"], str) and source["url"].startswith("https://"),
                    context + ": invalid reference URL")


def validate(raw):
    require(isinstance(raw, dict), "Catalog must be an object")
    require(raw.get("meta", {}).get("formatVersion") == 1, "Unsupported catalog format")
    target = raw["meta"]["target"]
    require(target["version"] == "1.60.1.70888" and target["interface"] == 16001, "Wrong client baseline")
    require(isinstance(raw.get("entities"), list), "Missing entities")
    seen = {}
    for obj in raw["entities"]:
        kind, ident = obj.get("type"), obj.get("id")
        require(kind in KINDS and type(ident) is int and ident > 0, "Invalid typed entity ID")
        key = (kind, ident)
        require(key not in seen, "Duplicate typed ID: %r" % (key,))
        require(isinstance(obj.get("name"), str) and obj["name"].strip(), "Entity name missing")
        require(obj.get("confidence") in CONFIDENCE, "Invalid confidence")
        validate_source(obj.get("provenance"), "Entity %r" % (key,))
        seen[key] = obj
    for recipe in raw.get("recipes", []):
        spell = recipe.get("spellId")
        require(type(spell) is int and ("spell", spell) in seen, "Orphaned recipe spell")
        for field in ("outputItemId", "recipeItemId"):
            ident = recipe.get(field)
            if ident is not None:
                require(type(ident) is int and ("item", ident) in seen, "Orphaned " + field)
        require(type(recipe.get("cookingSkill")) is int and recipe["cookingSkill"] >= 0,
                "Invalid cooking skill")
        require(recipe.get("confidence") in CONFIDENCE, "Invalid recipe confidence")
        validate_source(recipe.get("provenance"), "Recipe %s" % spell)
        require(isinstance(recipe.get("ingredients"), list), "Missing ingredients")
        for ing in recipe["ingredients"]:
            require(type(ing.get("itemId")) is int and ("item", ing["itemId"]) in seen,
                    "Orphaned ingredient")
            require(type(ing.get("amount")) is int and ing["amount"] > 0,
                    "Invalid ingredient amount")
    seen_equipment = set()
    for gear in raw.get("equipment", []):
        ident = gear.get("itemId")
        require(type(ident) is int and ("item", ident) in seen, "Orphaned equipment item")
        require(ident not in seen_equipment, "Duplicate equipment item")
        require(gear.get("type") in ("fishing_pole", "lure", "accessory"), "Invalid equipment type")
        require(gear.get("confidence") in CONFIDENCE, "Invalid equipment confidence")
        validate_source(gear.get("provenance"), "Equipment %s" % ident)
        seen_equipment.add(ident)
    seen_maps = set()
    for zone in raw.get("zones", []):
        mid = zone.get("mapId")
        require(type(mid) is int and ("zone", mid) in seen, "Orphaned zone map ID")
        require(mid not in seen_maps, "Duplicate zone map ID")
        require(zone.get("confidence") in CONFIDENCE, "Invalid zone confidence")
        validate_source(zone.get("provenance"), "Zone %s" % mid)
        bounds = zone.get("bounds")
        require(isinstance(bounds, dict) and all(
            type(bounds.get(k)) in (float, int) for k in ("left", "right", "top", "bottom")
        ), "Invalid zone geometry")
        seen_maps.add(mid)
    for category in ("vendors", "schools", "zones", "equipment", "observations"):
        require(isinstance(raw.get(category), list), "Missing list: " + category)
    return raw


def lua(value, level=0):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if type(value) in (int, float):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ", ".join(lua(v, level + 1) for v in value) + "}"
    if isinstance(value, dict):
        fields = []
        for key in sorted(value, key=lambda k: (type(k).__name__, str(k))):
            attr = key if isinstance(key, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) else "[" + lua(key) + "]
            fields.append(attr + " = " + lua(value[key], level + 1))
        return "{" + ", ".join(fields) + "}"
    raise ValueError("Unsupported value: " + repr(value))


def build(raw):
    validate(raw)
    return ("-- SPDX-License-Identifier: GPL-3.0-or-later\n"
            "-- GENERATED FILE. Edit database/catalog.json and run scripts/build_catalog.py\n"
            "local _, ns = ...\n"
            "ns.data.catalog = " + lua(raw) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="Reject stale generated output")
    args = ap.parse_args()
    raw = json.loads(INPUT.read_text(encoding="utf-8"))
    compiled = build(raw)
    if args.check:
        require(OUTPUT.is_file(), "Generated catalog is missing")
        require(OUTPUT.read_text(encoding="utf-8") == compiled, "Generated catalog is stale")
    else:
        OUTPUT.write_text(compiled, encoding="utf-8")
    print("Catalog valid: %d entities, %d recipes, %d observations" % (
        len(raw["entities"]), len(raw["recipes"]), len(raw["observations"])))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, json.JSONDecodeError) as e:
        print("Catalog error:", e, file=sys.stderr)
        sys.exit(1)
