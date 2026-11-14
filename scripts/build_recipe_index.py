#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile a sourced, *typed* recipe graph for WoW Forever.

Input edges MUST explicitly link a crafting spell to a teaching item. Vendor
observations are joined on the teaching item ID, not dish/recipe name.
An imported cookingSkill=1 does NOT establish a learning requirement.
"""
import argparse
import json
from pathlib import Path
from build_catalog import lua

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "database/catalog.json"
OBSERVED = ROOT / "database/observed/eg-cooking.json"
REFERENCES = ROOT / "database/sources/recipe-edges-v2.json"
JSON_OUT = ROOT / "database/recipe-index-v2.json"
LUA_OUT = ROOT / "FishingAtlas/Data/RecipeIndex.lua"
HEADER = ("-- SPDX-License-Identifier: GPL-3.0-or-later\n"
          "-- GENERATED: scripts/build_recipe_index.py; never edit this file by hand.\n"
          "-- Sources: database/catalog.json, observed/eg-cooking.json, sources/recipe-edges-v2.json.\n"
          "local _, ns = ...\n"
          "ns.data.recipeIndex = ")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def build(catalog, observed, references):
    require(references.get("schema") == "fishing-atlas.recipe-edges-v2/1",
            "Wrong explicit relationship schema")
    raw_references = references.get("edges", [])
    by_spell = {}
    for edge in raw_references:
        spell, item, skill = (edge.get("spellId"), edge.get("teachingItemId"),
                              edge.get("requiredSkill"))
        require(all(type(x) is int and x > 0 for x in (spell, item, skill)),
                "Recipe edges require exact spell/item/rank integers")
        require(spell not in by_spell, "Duplicate spell-to-item reference")
        require(isinstance(edge.get("url"), str)
                and edge["url"].startswith("https://"),
                "Reference evidence URL required")
        by_spell[spell] = edge
    sellers = {}
    for group in observed.get("vendors", {}).values():
        for entry in group:
            item = entry.get("itemId")
            require(type(item) is int and item > 0, "Vendor item ID missing")
            sellers.setdefault(item, []).append(entry)
    names = {e["id"]: e["name"] for e in catalog["entities"]
             if e["type"] == "spell"}
    rows, conflicts, seen = [], [], set()
    for r in catalog["recipes"]:
        spell = r["spellId"]
        require(spell not in seen, "Duplicate profession spell in catalog")
        seen.add(spell)
        require(spell in names, "Recipe spell missing typed entity")
        ref = by_spell.get(spell)
        teachers = observed.get("trainers", {}).get(str(spell), [])
        ranks = sorted({t["skillRank"] for t in teachers
                        if type(t.get("skillRank")) is int and t["skillRank"] > 0})
        if len(ranks) > 1:
            conflicts.append({"spellId": spell,
                              "issue": "conflicting_observed_trainer_ranks",
                              "ranks": ranks})
        if ref and any(rank != ref["requiredSkill"] for rank in ranks):
            conflicts.append({
                "spellId": spell, "issue": "trainer_rank_disagrees_with_reference",
                "referenceRank": ref["requiredSkill"], "ranks": ranks})
        learn = None
        if ref:
            learn = {"rank": ref["requiredSkill"], "source": ref["source"],
                     "sourceBuild": ref["sourceBuild"], "url": ref["url"]}
        elif len(ranks) == 1:
            learn = {"rank": ranks[0], "source": "forever_observed_trainer",
                     "sourceBuild": teachers[0]["sourceBuild"]}
        teaching_items = ([{"itemId": ref["teachingItemId"],
                            "source": ref["source"], "sourceBuild": ref["sourceBuild"],
                            "url": ref["url"]}] if ref else [])
        acquisitions = []
        for trainer in teachers:
            row = {"relation": "trainer_teaches_spell", "spellId": spell,
                   "npcId": trainer["npcId"], "name": trainer["name"],
                   "source": "forever_observed_trainer",
                   "sourceBuild": trainer["sourceBuild"]}
            for field in ("mapID", "x", "y", "installs", "seenOn"):
                if trainer.get(field) is not None:
                    row[field] = trainer[field]
            acquisitions.append(row)
        if ref:
            found = set()
            for seller in sellers.get(ref["teachingItemId"], []):
                identity = (seller["npcId"], seller["sourceBuild"])
                if identity in found:
                    continue
                found.add(identity)
                row = {"relation": "vendor_sells_item",
                       "itemId": ref["teachingItemId"],
                       "npcId": seller["npcId"], "name": seller["name"],
                       "source": "forever_observed_vendor",
                       "sourceBuild": seller["sourceBuild"]}
                for field in ("mapID", "x", "y", "installs", "seenOn"):
                    if seller.get(field) is not None:
                        row[field] = seller[field]
                acquisitions.append(row)
            for lead in ref.get("sources", []):
                relation = {"vendor": "vendor_sells_item",
                            "quest": "quest_rewards_item"}.get(lead["kind"])
                if not relation:
                    continue
                row = {"relation": relation, "itemId": ref["teachingItemId"],
                       "source": lead["source"], "name": lead["name"]}
                for field in ("npcId", "questId", "mapID", "x", "y"):
                    if lead.get(field) is not None:
                        row[field] = lead[field]
                acquisitions.append(row)
        acquisitions.sort(key=lambda row: (
            row["relation"], row.get("npcId", 0), row.get("questId", 0),
            row.get("sourceBuild", "")))
        source_build = r.get("sourceBuild")
        rows.append({
            "professionId": r.get("professionId") or 185,
            "profession": r.get("profession") or "Cooking",
            "spellId": spell, "clientRecipeId": None, "name": names[spell],
            "output": {"itemId": r["outputItemId"], "quantity": 1}
                      if r.get("outputItemId") else None,
            "reagents": [{"itemId": i["itemId"], "quantity": i["amount"]}
                         for i in r.get("ingredients", [])],
            "skills": {
                "learn": learn,
                "yellow": {"rank": r["yellowSkill"],
                           "source": "client_recipe_extract",
                           "sourceBuild": source_build}
                          if r.get("yellowSkill") else None,
                "grey": {"rank": r["greySkill"],
                         "source": "client_recipe_extract",
                         "sourceBuild": source_build}
                        if r.get("greySkill") else None,
            },
            "teachingItems": teaching_items,
            "acquisitions": acquisitions,
            "sourceBuild": source_build, "confidence": r["confidence"],
        })
    require(len(by_spell) == len(set(by_spell).intersection(seen)),
            "Reference teaching spell not present in canonical catalog")
    rows.sort(key=lambda row: row["spellId"])
    return {
        "schema": "fishing-atlas.recipe-index-v2/1",
        "meta": {
            "catalogSource": "database/catalog.json",
            "observations": "database/observed/eg-cooking.json",
            "references": "database/sources/recipe-edges-v2.json",
            "licenseCredit": "EG Link Cooking observations: Efficient Games CC BY 4.0; Blizzard game spell/item data. See DATA-LICENSES.txt",
            "sourceCommit": observed["meta"]["sourceCommit"],
            "notes": "No dish-name inference; client cookingSkill=1 excluded as learn requirement.",
        },
        "records": rows, "conflicts": conflicts,
        "coverage": {
            "total": len(rows),
            "learnRankKnown": sum(bool(row["skills"]["learn"]) for row in rows),
            "teachingItemKnown": sum(bool(row["teachingItems"]) for row in rows),
            "withAcquisition": sum(bool(row["acquisitions"]) for row in rows),
            "unresolvedLearn": sum(not row["skills"]["learn"] for row in rows),
        }
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true")
    args = p.parse_args()
    raw = build(json.loads(CATALOG.read_text(encoding="utf-8")),
                json.loads(OBSERVED.read_text(encoding="utf-8")),
                json.loads(REFERENCES.read_text(encoding="utf-8")))
    json_output = json.dumps(raw, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    lua_output = HEADER + lua(raw) + "\n"
    if args.check:
        require(JSON_OUT.read_text(encoding="utf-8") == json_output,
                "Generated Recipes v2 JSON index is stale")
        require(LUA_OUT.read_text(encoding="utf-8") == lua_output,
                "Generated Recipes v2 Lua index is stale")
    else:
        JSON_OUT.write_text(json_output, encoding="utf-8")
        LUA_OUT.write_text(lua_output, encoding="utf-8")
    print("Recipes v2: %d records, %d sourced learn ranks, %d teaching links, %d conflicts"
          % (raw["coverage"]["total"], raw["coverage"]["learnRankKnown"],
             raw["coverage"]["teachingItemKnown"], len(raw["conflicts"])))


if __name__ == "__main__":
    main()
