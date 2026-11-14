#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Generate unverified Classic school positions from GPLv3 CMaNGOS SQL.

This is offline build tooling; game clients never contact CMaNGOS. World
coordinates are transformed using the official Forever 70888 map bounds.
"""
import gzip
import hashlib
import io
import json
import re
from urllib.request import urlopen

from build_catalog import ROOT, lua

COMMIT = "09000ea8d7333856727204e4e2d30f772149b7a8"
FILE = "Full_DB/ClassicDB_1_12_1_z2815.sql.gz"
URL = "https://raw.githubusercontent.com/cmangos/classic-db/" + COMMIT + "/" + FILE
SOURCE = "https://github.com/cmangos/classic-db/tree/" + COMMIT
GO_ROW = re.compile(r"\((\d+),(\d+),(\d+),(\d+),(-?[\d.]+),(-?[\d.]+),")
TEMPLATE_ROW = re.compile(r"\((\d+),\d+,\d+,'((?:\\.|[^'\\])*)'")
NPC_ROW = re.compile(r"\((\d+),'((?:\\.|[^'\\])*)'")
PREFIX = "INSERT INTO " + chr(96)
SCHOOL = {
    "school of deviate fish": "School of Deviate Fish",
    "sagefish school": "School of Sagefish",
    "greater sagefish school": "Greater Sagefish School",
    "oily blackmouth school": "Oily Blackmouth School",
    "firefin snapper school": "Firefin Snapper School",
    "stonescale eel swarm": "Stonescale Eel Swarm",
    "floating wreckage": "Floating Wreckage",
    "floating debris": "Floating Debris",
    "waterlogged wreckage": "Waterlogged Wreckage",
    "patch of elemental water": "Patch of Elemental Water",
    "muddy churning waters": "Muddy Churning Waters",
    "school of tastyfish": "School of Tastyfish",
}


def project(zones, continent, world_x, world_y):
    candidates = []
    for zone in zones:
        if zone.get("continentId") != continent:
            continue
        bounds = zone["bounds"]
        dx = bounds["right"] - bounds["left"]
        dy = bounds["bottom"] - bounds["top"]
        if not dx or not dy:
            continue
        x = (world_y - bounds["left"]) / dx
        y = (world_x - bounds["top"]) / dy
        if 0 <= x <= 1 and 0 <= y <= 1:
            candidates.append((abs(dx * dy), zone["mapId"], round(x, 6), round(y, 6)))
    if not candidates:
        return None
    _, map_id, x, y = min(candidates)
    return map_id, x, y


def npc_candidates(catalog, observed):
    fish_items = {e["id"] for e in catalog["entities"]
                  if e.get("type") == "item" and e.get("category") in
                  ("fish", "fishing_pole", "lure")}
    fish_items.update(int(id) for id in observed.get("fishing", {}))
    fish_items.update(int(id) for id in observed.get("poolItems", {}))
    relevant = set(fish_items)
    for recipe in catalog["recipes"]:
        ingredients = {r["itemId"] for r in recipe.get("ingredients", [])}
        if ingredients & fish_items:
            relevant.update(ingredients)
            if isinstance(recipe.get("outputItemId"), int):
                relevant.add(recipe["outputItemId"])
    return {r["npcId"] for item in relevant
            for r in observed.get("drops", {}).get(str(item), [])
            if isinstance(r.get("npcId"), int)}


def generate(raw, catalog, observed):
    templates = {}
    objects = []
    names = {}
    wanted_npcs = npc_candidates(catalog, observed)
    with gzip.GzipFile(fileobj=io.BytesIO(raw)) as f:
        for row in f:
            line = row.decode("utf-8", "replace")
            if line.startswith(PREFIX + "gameobject_template" + chr(96)):
                for match in TEMPLATE_ROW.finditer(line):
                    name = match.group(2).replace("\\'", "'")
                    if name.lower() in SCHOOL:
                        templates[int(match.group(1))] = SCHOOL[name.lower()]
            elif line.startswith(PREFIX + "gameobject" + chr(96)):
                for match in GO_ROW.finditer(line):
                    objects.append((int(match.group(2)), int(match.group(3)),
                                    float(match.group(5)), float(match.group(6))))
            elif line.startswith(PREFIX + "creature_template" + chr(96)):
                for match in NPC_ROW.finditer(line):
                    entry = int(match.group(1))
                    if entry in wanted_npcs:
                        names[entry] = match.group(2).replace("\\'", "'")
    locations = {name: [] for name in set(SCHOOL.values())}
    dedupe = set()
    for entry, continent, world_x, world_y in objects:
        name = templates.get(entry)
        if not name:
            continue
        point = project(catalog["zones"], continent, world_x, world_y)
        if not point:
            continue
        map_id, x, y = point
        key = (name, map_id, x, y, entry)
        if key in dedupe:
            continue
        dedupe.add(key)
        locations[name].append({"mapID": map_id, "x": x, "y": y,
                                "objectId": entry, "source": "cmangos_classic_reference"})
    for points in locations.values():
        points.sort(key=lambda p: (p["mapID"], p["x"], p["y"], p["objectId"]))
    expected = {(45.06, 22.19), (45.47, 22.72), (44.67, 23.57),
                (45.11, 23.64), (46.34, 37.62)}
    found = {(round(p["x"] * 100, 2), round(p["y"] * 100, 2))
             for p in locations["School of Deviate Fish"] if p["mapID"] == 1413}
    if not expected.issubset(found):
        raise ValueError("School coordinate transform failed Barrens cross-check")
    total = sum(len(v) for v in locations.values())
    if len(templates) < 8 or total < 100:
        raise ValueError("School spawn references missing or source schema changed")
    meta = {"source": SOURCE, "sourceArchive": URL,
            "sourceSha256": hashlib.sha256(raw).hexdigest(),
            "license": "GPL-3.0-or-later; Blizzard game content notice",
            "mapBoundsBuild": "Forever 1.60.1.70888",
            "status": "classic_reference_unverified", "totalLocations": total}
    return {"meta": meta, "schools": locations,
            "npcNames": {id: names[id] for id in sorted(names)}}


def lua_pack(name, data, meta):
    return ("-- SPDX-License-Identifier: GPL-3.0-or-later\n"
            "-- CMaNGOS classic-db GPLv3: " + SOURCE + "\n"
            "-- Archive SHA-256: " + meta["sourceSha256"] + "\n"
            "-- Historical references only; NOT currently active Forever pools.\n"
            "-- Generated by scripts/import_classic_schools.py; do not edit.\n"
            "local _, ns = ...\nns.data." + name + " = " + lua(data) + "\n")


def main():
    with urlopen(URL, timeout=80) as response:
        raw = response.read(30_000_001)
    if len(raw) > 30_000_000 or not raw.startswith(b"\x1f\x8b"):
        raise ValueError("Invalid historical source archive")
    catalog = json.loads((ROOT / "database" / "catalog.json").read_text())
    observed = json.loads((ROOT / "database" / "observed" /
                           "everloot-normalized.json").read_text())
    data = generate(raw, catalog, observed)
    print("Historical school locations:", data["meta"]["totalLocations"])
    print("Named fishing-drop NPCs:", len(data["npcNames"]))
    print("Source SHA-256:", data["meta"]["sourceSha256"])
    path = ROOT / "database" / "reference" / "cmangos-school-spawns.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    (ROOT / "FishingAtlas" / "Data" / "ClassicSchoolLocations.lua").write_text(
        lua_pack("classicSchoolLocations", data["schools"], data["meta"]))
    (ROOT / "FishingAtlas" / "Data" / "ClassicNPCNames.lua").write_text(
        lua_pack("classicNpcNames", data["npcNames"], data["meta"]))


if __name__ == "__main__":
    main()
