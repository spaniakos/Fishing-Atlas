#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Audit EVERY fishing-scoped item against offline observations and references.

This is coverage, not an availability estimator. No edge means UNKNOWN, never
"not obtainable". Everloot observations (CC BY-SA) and historical game data
(Blizzard/CMaNGOS, separate license) must not be confused.
"""
import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from build_catalog import ROOT


def data(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def parse_vendors(text):
    found = defaultdict(set)
    for match in re.finditer(r"id=(\d+),items=\{([^}]*)\}", text):
        npc = int(match.group(1))
        for item in re.findall(r"\d+", match.group(2)):
            found[int(item)].add(npc)
    return found


def parse_acquisition(text):
    result = defaultdict(Counter)
    entries = list(re.finditer(r"\[(\d+)\]\s*=\s*\{", text))
    for i, match in enumerate(entries):
        section = text[match.end(): entries[i + 1].start()
                       if i + 1 < len(entries) else len(text)]
        for kind in re.findall(r'kind\s*=\s*"([a-z_]+)"', section):
            result[int(match.group(1))][kind] += 1
    return result


def expand():
    cat = data("database/catalog.json")
    obs = data("database/observed/everloot-normalized.json")
    game = data("database/game-files/everloot-gamefiles.json")
    names = {e["id"]: e["name"] for e in cat["entities"]
             if e["type"] == "item"}
    for idstr, rec in obs.get("itemNames", {}).items():
        if isinstance(rec, dict) and isinstance(rec.get("name"), str):
            if names.get(int(idstr), "").startswith("Item #"):
                names[int(idstr)] = rec["name"]
    fishing = {int(x) for x in obs.get("fishing", {})}
    pools = {int(x) for x in obs.get("poolItems", {})}
    fish = {e["id"] for e in cat["entities"]
            if e["type"] == "item" and e.get("category") == "fish"}
    # The full independent reference-zone pack also contributes fishing
    # references. Parse the generated Lua table rather than assuming all
    # fishing loot is a biological fish.
    reftext = (ROOT / "FishingAtlas/Data/ReferenceFishZones.lua").read_text()
    reference_counts = Counter(int(x) for x in re.findall(r"\bid=(\d+)", reftext))
    reference_fish = set(reference_counts)
    catchable = fish | fishing | pools | reference_fish
    equipment = {e["id"] for e in cat["entities"]
                 if e["type"] == "item"
                 and e.get("category") in ("fishing_pole", "lure")}
    root = catchable | equipment
    scoped = set(root) | {8959}
    cat_recipes = cat["recipes"]
    game_recipes = game.get("recipes", {})
    # Only material edges attached to a fish-rooted recipe; no unrelated
    # Tailoring or ordinary Azeroth drops may inflate the fishing atlas.
    all_recipes = {str(r["spellId"]): r for r in cat_recipes}
    all_recipes.update(game_recipes)
    crafting = defaultdict(set)
    ingredient_of = defaultdict(set)
    for sid, recipe in all_recipes.items():
        ingredients = recipe.get("ingredients") or recipe.get("reagents") or []
        ids = {int(r["itemId"]) for r in ingredients
               if isinstance(r.get("itemId"), int)}
        out = recipe.get("outputItemId")
        if ids & (root | {8959}):
            scoped.update(ids)
            if isinstance(out, int):
                scoped.add(out)
                crafting[out].add(int(sid))
            for item in ids:
                ingredient_of[item].add(int(sid))
            recipe_item = recipe.get("recipeItemId")
            if isinstance(recipe_item, int):
                scoped.add(recipe_item)
    # The separate client item-to-spell graph can also supply crafting edges.
    for edge in game.get("relations", []):
        if edge.get("fromKind") == "item" and edge.get("rel") == "created_by":
            item, spell = edge.get("fromId"), edge.get("toId")
            if isinstance(item, int) and item in scoped and isinstance(spell, int):
                crafting[item].add(spell)
    refs = parse_vendors((ROOT / "FishingAtlas/Data/ReferenceVendors.lua").read_text())
    acquired = parse_acquisition(
        (ROOT / "FishingAtlas/Data/ReferenceAcquisition.lua").read_text())
    out = []
    for item in sorted(scoped):
        vendors = obs.get("vendorItems", {}).get(str(item), [])
        drops = obs.get("drops", {}).get(str(item), [])
        record = {
            "id": item,
            "name": names.get(item, "Unresolved item #" + str(item)),
            "group": "fishing_catch" if item in catchable
                     else "equipment" if item in equipment else "associated_item",
            "evidence": {
                "observedFishingZones": len(obs.get("fishing", {}).get(str(item), [])),
                "observedPoolSources": len(obs.get("poolItems", {}).get(str(item), [])),
                "historicalFishingZoneReferences": reference_counts[item],
                "observedCreatureDrops": len(drops),
                "observedVendorSellers": len(vendors),
                "historicalVendorSellers": len(refs.get(item, set())),
                "clientCraftSpells": len(crafting.get(item, set())),
                "usedAsIngredientBy": len(ingredient_of.get(item, set())),
                "historicalObjectLoot": acquired[item]["object_loot"],
                "historicalCreatureLoot": acquired[item]["creature_drop"],
                "historicalQuestRewards": acquired[item]["quest_reward"],
                "historicalCraftReferences": acquired[item]["crafted"],
            },
        }
        record["sourceStatus"] = "documented_reference_or_observation" if any(
            record["evidence"].values()) else "unknown_not_proven_absent"
        out.append(record)
    counts = Counter(r["group"] for r in out)
    unknown = [r for r in out if r["sourceStatus"] == "unknown_not_proven_absent"]
    return {"meta": {
        "purpose": "Fishing-only source coverage; not server availability",
        "observedAt": obs.get("meta", {}).get("dataAsOf"),
        "observationCredit": "Everloot, CC BY-SA 4.0",
        "referenceCredit": "Blizzard-derived client metadata and separate GPLv3 historical references",
        "noSourceMeans": "unknown_not_proven_absent",
        "counts": dict(counts),
        "unknownSources": len(unknown),
        "totalRecords": len(out),
    }, "items": out}


def markdown(audit):
    lines = [
        "# Fishing Atlas source coverage audit",
        "",
        "This file is generated from **all currently bundled offline fishing-relevant"
        " records**. It does not claim exhaustive Forever server loot, permanent"
        " vendor stock, or currently spawned schools.",
        "",
        "Everloot observation evidence is CC BY-SA 4.0. Client files are"
        " Blizzard-derived and historical references are separately credited.",
        "",
        f"Total indexed fishing-relevant item IDs: **{audit['meta']['totalRecords']}**.",
        f"Items with no known acquisition/craft/ingredient edge:"
        f" **{audit['meta']['unknownSources']}**. These are **UNKNOWN**, not unobtainable.",
        "",
        "| ID | Name | Group | Fishing/pool/ref | Vendors obs/ref | Creature drops | Craft | Quest/object |",
        "|---:|---|---|---:|---:|---:|---:|---:|",
    ]
    for item in audit["items"]:
        e = item["evidence"]
        name = item["name"].replace("|", r"\|")
        lines.append(
            f"| {item['id']} | {name} | {item['group']} | "
            f"{e['observedFishingZones']}/{e['observedPoolSources']}/"
            f"{e['historicalFishingZoneReferences']} | "
            f"{e['observedVendorSellers']}/{e['historicalVendorSellers']} | "
            f"{e['observedCreatureDrops']} | {e['clientCraftSpells']} | "
            f"{e['historicalQuestRewards']}/{e['historicalObjectLoot']} |")
    lines += [
        "",
        "## Interpretation",
        "",
        "Every zero is a **missing evidence relationship in the bundled snapshot**.",
        "A vendor edge establishes a sale observation/reference, not that the item"
        " can be fished. A creature/object edge is not a fishing cast. Historical"
        " quest, vendor and object sources may differ on Forever build 70938.",
        "",
    ]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    audit = expand()
    print(json.dumps(audit["meta"], indent=2))
    gear = [r for r in audit["items"] if r["group"] == "equipment"]
    print("Gear source coverage:")
    for item in gear:
        print(f" {item['id']:5d} {item['name'][:34]:34s}"
              f"  {item['sourceStatus']}")
    if args.write:
        out = ROOT / "database/audit/fishing-source-coverage.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
        (ROOT / "docs/FISHING-SOURCE-AUDIT.md").write_text(markdown(audit) + "\n")


if __name__ == "__main__":
    main()
