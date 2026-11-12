#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import the reviewed Forever 70888 Cooking/Fishing client extract into canonical JSON.

Run from repo root: python3 scripts/rebuild_client_recipes.py
Then: python3 scripts/build_catalog.py
"""
import copy
import json
from pathlib import Path
from build_catalog import INPUT, validate

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "database" / "sources" / "client-recipes-70888.json"


def merge(base, raw):
    if raw.get("build", {}).get("version") != "1.60.1.70888":
        raise ValueError("Wrong Forever client build")
    if raw.get("schema") != "fishing-atlas.client-recipes/1":
        raise ValueError("Unsupported source schema")
    obj = copy.deepcopy(base)
    src = {
        "source": "wow_forever_client_recipe_extract",
        "build": "1.60.1.70888",
        "url": raw["sourceUrl"],
        "verifiedInForever": False,
    }
    entries = {(e["type"], e["id"]): e for e in obj["entities"]}
    recipes = {r["spellId"]: r for r in obj["recipes"]}

    def add_entity(kind, ident, category):
        if type(ident) is not int or ident <= 0:
            raise ValueError("Invalid extracted ID")
        key = (kind, ident)
        if key not in entries:
            e = {
                "type": kind,
                "id": ident,
                "name": ("Spell #" if kind == "spell" else "Item #") + str(ident),
                "category": category,
                "confidence": "verified_client",
                "provenance": [src],
            }
            entries[key] = e
            obj["entities"].append(e)
        else:
            e = entries[key]
            if not any(s["source"] == src["source"] and s["build"] == src["build"]
                       for s in e["provenance"]):
                e["provenance"].append(src)
            e["confidence"] = "verified_client"

    for profession in raw["professions"]:
        if profession["name"] not in ("Cooking", "Fishing"):
            raise ValueError("Unexpected profession")
        for spell_id, output_id, minimum, yellow, grey, reagents in profession["recipes"]:
            add_entity("spell", spell_id, profession["name"].lower())
            if output_id > 0:
                add_entity("item", output_id,
                           "crafted_output" if profession["name"] == "Cooking" else "fishing_craft")
            ingredients = []
            for item_id, amount in reagents:
                add_entity("item", item_id, "ingredient")
                ingredients.append({"itemId": item_id, "amount": amount})
            r = recipes.get(spell_id)
            if r is None:
                r = {
                    "spellId": spell_id,
                    "outputItemId": output_id or None,
                    "cookingSkill": minimum,
                    "ingredients": ingredients,
                    "confidence": "verified_client",
                    "provenance": [src],
                }
                recipes[spell_id] = r
                obj["recipes"].append(r)
            else:
                r["outputItemId"] = output_id or None
                r["cookingSkill"] = minimum
                r["ingredients"] = ingredients
                r["confidence"] = "verified_client"
                if not any(s["source"] == src["source"] for s in r["provenance"]):
                    r["provenance"].append(src)
            r.update({
                "profession": profession["name"],
                "professionId": profession["id"],
                "yellowSkill": yellow,
                "greySkill": grey,
                "sourceBuild": "1.60.1.70888",
            })

    obj["entities"].sort(key=lambda x: (x["type"], x["id"]))
    obj["recipes"].sort(key=lambda x: x["spellId"])
    if obj["meta"].get("status") == "seed_only":
        obj["meta"]["status"] = "client_recipes_imported_partial"
    obj["meta"]["clientRecipeSource"] = {
        "source": raw["sourceUrl"],
        "build": "1.60.1.70888",
        "extractedAt": raw["build"]["extractedAt"],
        "credit": "Game data © Blizzard Entertainment, Inc.; extraction from Everloot; see docs/DATABASE-IMPORTS.md",
    }
    validate(obj)
    return obj


def main():
    base = json.loads(INPUT.read_text(encoding="utf-8"))
    raw = json.loads(SOURCE.read_text(encoding="utf-8"))
    updated = merge(base, raw)
    INPUT.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Cooking/Fishing client recipes: %d, entities: %d" % (
        len(updated["recipes"]), len(updated["entities"])))


if __name__ == "__main__":
    main()
