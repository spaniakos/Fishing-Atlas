#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import build-matched Everloot client catalogs as *unconfirmed* Blizzard game data.

No Everloot addon/API key required. Fetch immutable upstream GitHub revision,
verify file-specific build/config and record source digests before emitting Lua.
Never mix these records with independently observed Everloot CC BY-SA data.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from build_catalog import ROOT, lua

TARGET = "1.60.1.70888"
RAW = "https://raw.githubusercontent.com/Everloot/everloot/"
COMMIT = "https://api.github.com/repos/Everloot/everloot/commits/main"
PREFIX = "web/src/data/game-data/"
OUTPUT = ROOT / "FishingAtlas" / "Data" / "EverlootGameFiles.lua"
JSON = ROOT / "database" / "game-files" / "everloot-gamefiles.json"
NOTICE = ("Game data © Blizzard Entertainment, Inc., read from the public client; "
          "not under Everloot's licence. Column names from WoWDBDefs "
          "(https://github.com/wowdev/WoWDBDefs), CC BY-SA 4.0.")


def request(url, limit):
    with urlopen(Request(url, headers={
        "User-Agent": "FishingAtlas-gamefile-import/0.99.6",
        "Accept": "application/json",
    }), timeout=60) as response:
        raw = response.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Source file exceeds size limit")
    return raw


def upstream():
    commit = json.loads(request(COMMIT, 1_000_000))["sha"]
    if not isinstance(commit, str) or len(commit) != 40:
        raise ValueError("Invalid upstream commit hash")
    sources = {}
    for name in ("client-recipes.json", "client-layer.json"):
        url = RAW + commit + "/" + PREFIX + name
        body = request(url, 8_000_000)
        sources[name] = {"data": json.loads(body), "sha256": hashlib.sha256(body).hexdigest(),
                         "url": url}
    return commit, sources


def positive(v):
    return type(v) is int and v > 0


def normalize(recipes_source, layer_source, catalog, observed, commit, hashes):
    recipe_data = recipes_source
    layer = layer_source
    for obj, schema in ((recipe_data, "everloot.client-recipes/1"),
                        (layer, "everloot.client-layer/2")):
        if obj.get("schema") != schema:
            raise ValueError("Unsupported upstream client schema: " + str(obj.get("schema")))
        if obj.get("build", {}).get("version") != TARGET:
            raise ValueError("Client build mismatch; refuse mixing versions")
        if obj.get("credit") != NOTICE:
            raise ValueError("Upstream client-data credit changed; review license")
    if recipe_data["build"].get("buildConfig") != layer["build"].get("buildConfig"):
        raise ValueError("Client source build configurations differ")
    if not isinstance(layer.get("items"), list) or not isinstance(layer.get("edges"), list):
        raise ValueError("Incomplete client-layer data")
    tracked = {e["id"] for e in catalog["entities"] if e["type"] == "item"}
    for key in ("vendorItems", "drops", "fishing", "poolItems", "itemNames"):
        tracked.update(int(i) for i in observed.get(key, {}))
    recipes = {}
    for profession in recipe_data.get("professions", []):
        if profession.get("name") not in ("Cooking", "Fishing"):
            continue
        for row in profession.get("recipes", []):
            if not isinstance(row, list) or len(row) != 6 or not positive(row[0]):
                continue
            spell, item_id, minimum, yellow, grey, reagents = row
            required = []
            for ing in reagents:
                if isinstance(ing, list) and len(ing) == 2 and positive(ing[0]) and positive(ing[1]):
                    required.append({"itemId": ing[0], "count": ing[1]})
                    tracked.add(ing[0])
            recipes[spell] = {"profession": profession["name"],
                              "outputItemId": item_id if positive(item_id) else None,
                              "minimumSkill": minimum if positive(minimum) else None,
                              "yellow": yellow if positive(yellow) else None,
                              "grey": grey if positive(grey) else None,
                              "reagents": required}
            if positive(item_id):
                tracked.add(item_id)
    classes = {r["id"]: r["name"] for r in layer.get("categories", {}).get("classes", [])}
    subclasses = {(r["classId"], r["id"]): r["name"]
                  for r in layer.get("categories", {}).get("subclasses", [])}
    categories = {}
    for row in layer["items"]:
        if not isinstance(row, list) or len(row) != 5 or row[0] not in tracked:
            continue
        item_id, class_id, subclass_id, slot, quality = row
        categories[item_id] = {
            "classId": class_id, "subclassId": subclass_id,
            "className": classes.get(class_id), "subclassName": subclasses.get((class_id, subclass_id)),
            "slot": slot, "quality": quality}
    relations = []
    for row in layer["edges"]:
        if not isinstance(row, list) or len(row) != 5:
            continue
        frm, fid, rel, to, tid = row
        if rel not in ("created_by", "reagent_for", "part_of_set", "in_skill_line"):
            continue
        if (frm == "item" and fid in tracked) or (to == "item" and tid in tracked) or (
                frm == "spell" and fid in recipes) or (to == "spell" and tid in recipes):
            relations.append({"fromKind": frm, "fromId": fid,
                              "rel": rel, "toKind": to, "toId": tid})
    if len(recipes) < 100 or not categories:
        raise ValueError("Client catalog suspiciously empty; refusing partial import")
    return {
        "meta": {"source": "Everloot public client game-file catalog",
                 "sourceUrl": RAW + commit + "/" + PREFIX,
                 "upstreamCommit": commit, "sourceSha256": hashes,
                 "credit": NOTICE, "build": TARGET,
                 "buildConfig": recipe_data["build"]["buildConfig"],
                 "extractedAt": recipe_data["build"].get("extractedAt"),
                 "status": "game_files_unconfirmed",
                 "license": "Blizzard game files; not CC BY-SA observed data"},
        "categories": categories, "recipes": recipes, "relations": relations,
    }


def encode_lua(value):
    return ("-- Game data © Blizzard Entertainment, Inc.\n"
            "-- Found in game files, UNCONFIRMED. Not Everloot's observed CC BY-SA data.\n"
            "-- SOURCE COMMIT AND CHECKSUMS LIVE IN ns.data.gameFiles.meta.\n"
            "-- Generated by scripts/import_everloot_client_git.py; DO NOT EDIT.\n"
            "local _, ns = ...\nns.data.gameFiles = " + lua(value) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = ap.parse_args()
    commit, sources = upstream()
    cat = json.loads((ROOT / "database" / "catalog.json").read_text(encoding="utf-8"))
    obs = json.loads((ROOT / "database" / "observed" / "everloot-normalized.json").read_text(encoding="utf-8"))
    result = normalize(sources["client-recipes.json"]["data"], sources["client-layer.json"]["data"],
                       cat, obs, commit, {k: v["sha256"] for k, v in sources.items()})
    source = json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    lua_source = encode_lua(result)
    if args.check:
        if JSON.read_text(encoding="utf-8") != source or OUTPUT.read_text(encoding="utf-8") != lua_source:
            raise ValueError("Existing generated client data differs from upstream revision")
    else:
        JSON.parent.mkdir(parents=True, exist_ok=True)
        JSON.write_text(source, encoding="utf-8")
        OUTPUT.write_text(lua_source, encoding="utf-8")
    print("Pinned Everloot game-file source commit:", commit)
    print("Build:", TARGET, "| Cooking/Fishing recipes:", len(result["recipes"]),
          "| relevant item categories:", len(result["categories"]),
          "| relevant item-spell edges:", len(result["relations"]))
    print(NOTICE)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, HTTPError, URLError) as error:
        print("Game-file import error:", error, file=sys.stderr)
        sys.exit(1)
