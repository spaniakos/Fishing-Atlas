#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build an attributed, privacy-minimized offline Everloot observation pack.

Input: an Everloot corpus.ndjson bulk export, a JSON records list, a single
/api/corpus/public JSON page, or --fetch for the paginated public API.
No upload/install identity is ever emitted into generated game data.

Usage:
 python3 scripts/import_everloot.py --input /path/to/corpus.ndjson --write
 python3 scripts/import_everloot.py --input /path/to/corpus.ndjson --check
 python3 scripts/import_everloot.py --fetch --write  # optional EVERLOOT_API_KEY
"""
import argparse
import collections
import hashlib
import json
import os
import re
import statistics
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import Request, urlopen

from build_catalog import ROOT, lua

API = "https://everloot.app/api/corpus/public"
CREDIT = "Data from Everloot (https://everloot.app), CC BY-SA 4.0."
LUA = ROOT / "FishingAtlas" / "Data" / "EverlootObserved.lua"
JSON = ROOT / "database" / "observed" / "everloot-normalized.json"
DIFF = ROOT / "database" / "observed" / "last-diff.json"
TARGET = "1.60.1.70888"


def positive(value):
    return type(value) is int and value > 0


def point(row):
    mid = row.get("mapId")
    x, y = row.get("x"), row.get("y")
    if not positive(mid) or type(x) not in (float, int) or type(y) not in (float, int):
        return None
    if not 0 <= x <= 100 or not 0 <= y <= 100:
        return None
    return (mid, round(x / 100, 5), round(y / 100, 5))


def records_from_json(value):
    if type(value) is list:
        return value, None
    if isinstance(value, dict) and isinstance(value.get("records"), list):
        return value["records"], value.get("dataAsOf")
    raise ValueError("Input must be an NDJSON corpus or a JSON records array/page")


def load_file(path):
    raw = path.read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    if path.suffix.lower() == ".ndjson":
        records = [json.loads(line) for line in raw.decode("utf-8").splitlines() if line.strip()]
        asof = None
    else:
        records, asof = records_from_json(json.loads(raw))
    return records, asof, sha


def load_live():
    key = os.getenv("EVERLOOT_API_KEY", "").strip()
    limit = 5000 if key else 500
    headers = {"User-Agent": "FishingAtlas-offline-import/0.99.6"}
    if key:
        headers["Authorization"] = "Bearer " + key
    for attempt in range(3):
        url = API + "?limit=" + str(limit)
        records, asof, pages = [], None, 0
        while url:
            pages += 1
            if pages > 20000:
                raise ValueError("Exceeded maximum pages")
            req = Request(url, headers=headers)
            try:
                with urlopen(req, timeout=40) as response:
                    page = json.load(response)
            except HTTPError as error:
                if error.code == 429:
                    raise ValueError("Everloot rate limit exceeded; use bulk corpus.ndjson or a free API key")
                raise ValueError("Everloot HTTP error " + str(error.code))
            except (URLError, TimeoutError) as error:
                raise ValueError("Everloot unavailable; this is NOT an empty corpus: " + str(error))
            if not isinstance(page, dict) or not isinstance(page.get("records"), list):
                raise ValueError("Invalid corpus page or unavailable source")
            page_asof = page.get("dataAsOf")
            if pages > 1 and page_asof != asof:
                break  # Snapshot changed: discard all and restart.
            asof = page_asof
            records.extend(page["records"])
            url = urljoin(API, page["next"]) if page.get("next") else None
        else:
            # Raw records never need to be stored in git.
            digest = hashlib.sha256(json.dumps(records, sort_keys=True).encode("utf-8")).hexdigest()
            return records, asof, digest
    raise ValueError("Everloot snapshot changed repeatedly; retry after the next refresh")


def add_vote(group, key, install, count=1):
    row = group.setdefault(key, {"installs": set(), "reports": 0})
    row["installs"].add(install)
    row["reports"] += count


def votes(group, key):
    row = group[key]
    return {"installs": len(row["installs"]), "reports": row["reports"]}


def normalize(records, data_asof, digest):
    # Every emitted fact is keyed on game-world IDs, not installation identity.
    item_names, npc_names = {}, {}
    vendor, drops, fishing, pools, school_positions = {}, {}, {}, {}, {}
    npc_positions, trainers, recipes = {}, {}, {}
    object_names, object_positions = {}, {}
    dedupe = set()
    kinds = collections.Counter()
    for row in records:
        if not isinstance(row, dict) or not isinstance(row.get("kind"), str):
            continue
        install = row.get("installId")
        # Refuse to call anonymous/invalid rows independent evidence.
        if not isinstance(install, str) or not re.fullmatch(r"pub-[0-9a-f]{32}", install):
            continue
        event = row.get("eventId")
        if event:
            key = (install, event)
            if key in dedupe:
                continue
            dedupe.add(key)
        kind = row["kind"]
        kinds[kind] += 1
        if kind == "item_seen" and positive(row.get("itemId")) and isinstance(row.get("name"), str):
            add_vote(item_names, (row["itemId"], row["name"]), install)
        elif kind == "npc_sighting" and positive(row.get("npcId")):
            npc = row["npcId"]
            if isinstance(row.get("name"), str):
                add_vote(npc_names, (npc, row["name"]), install)
            pos = point(row)
            if pos and row.get("positionKind") in ("npc", "vignette", "interaction"):
                # A 2%-wide spatial cell makes small position disagreements visible.
                # Interaction is *player near NPC*, never an exact spawn.
                map_id, x, y = pos
                bucket = (npc, map_id, round(x * 50), round(y * 50),
                          row.get("positionKind") == "interaction")
                add_vote(npc_positions, bucket, install)
        elif kind == "vendor" and positive(row.get("vendorNpcId")):
            for entry in row.get("items", []):
                if isinstance(entry, dict) and positive(entry.get("itemId")):
                    add_vote(vendor, (entry["itemId"], row["vendorNpcId"]), install)
        elif kind == "loot":
            if (row.get("lootType") == "kill" and
                    row.get("sourceEvidence") == "loot-api" and positive(row.get("sourceNpcId"))):
                for entry in row.get("items", []):
                    if isinstance(entry, dict) and positive(entry.get("itemId")):
                        add_vote(drops, (entry["itemId"], row["sourceNpcId"]), install)
            if row.get("lootType") == "fishing":
                pos = point(row)
                for entry in row.get("items", []):
                    if not isinstance(entry, dict) or not positive(entry.get("itemId")):
                        continue
                    if pos:
                        add_vote(fishing, (entry["itemId"], pos[0]), install)
                    if positive(row.get("sourceObjectId")) and row.get("gatherKind") == "fishing":
                        add_vote(pools, (entry["itemId"], row["sourceObjectId"]), install)
        elif kind == "object_sighting" and positive(row.get("objectId")):
            oid = row["objectId"]
            if isinstance(row.get("name"), str):
                add_vote(object_names, (oid, row["name"]), install)
            pos = point(row)
            if pos:
                map_id, x, y = pos
                bucket = (oid, map_id, round(x * 50), round(y * 50))
                add_vote(object_positions, bucket, install)
        elif kind == "recipe_observed" and positive(row.get("recipeId")):
            recipe = row["recipeId"]
            if positive(row.get("productItemId")):
                add_vote(recipes, (recipe, row["productItemId"], str(row.get("recipe", ""))), install)
        elif kind == "trainer_seen" and positive(row.get("trainerNpcId")) and isinstance(row.get("recipe"), str):
            add_vote(trainers, (row["recipe"], row["trainerNpcId"]), install)

    def best_name(group, ident):
        options = [(key[1], votes(group, key)["installs"])
                   for key in group if key[0] == ident]
        # Names are only exported if three independent installs agree on same spelling.
        options = [(name, count) for name, count in options if count >= 3]
        if not options:
            return None
        return sorted(options, key=lambda rec: (-rec[1], rec[0]))[0][0]

    result = {
        "meta": {"credit": CREDIT, "license": "CC-BY-SA-4.0",
                 "licenseUrl": "https://creativecommons.org/licenses/by-sa/4.0/",
                 "sourceUrl": API, "dataAsOf": data_asof,
                 "targetBuild": TARGET, "sourceSha256": digest,
                 "recordCounts": dict(sorted(kinds.items()))},
        "itemNames": {}, "npcs": {}, "vendorItems": {}, "drops": {},
        "fishing": {}, "poolItems": {}, "schools": [], "recipes": {}, "trainers": {}
    }
    for item_id in sorted({key[0] for key in item_names}):
        name = best_name(item_names, item_id)
        if name:
            result["itemNames"][item_id] = {"name": name}
    npc_ids = {key[0] for key in npc_names} | {key[0] for key in npc_positions}
    npc_ids |= {key[1] for key in vendor} | {key[1] for key in drops}
    for npc in sorted(npc_ids):
        name = best_name(npc_names, npc)
        spots = []
        for key in sorted(npc_positions):
            if key[0] != npc:
                continue
            v = votes(npc_positions, key)
            if v["installs"] < 1:
                continue
            _, mid, gx, gy, near = key
            spots.append({"mapID": mid, "x": gx / 50, "y": gy / 50,
                          "installs": v["installs"], "near": near})
        result["npcs"][npc] = {"name": name, "spots": spots}
    for (item, npc) in sorted(vendor):
        v = votes(vendor, (item, npc))
        result["vendorItems"].setdefault(item, []).append({"npcId": npc, **v})
    for (item, npc) in sorted(drops):
        v = votes(drops, (item, npc))
        result["drops"].setdefault(item, []).append({"npcId": npc,
            "installs": v["installs"], "windows": v["reports"]})
    for (item, mid) in sorted(fishing):
        v = votes(fishing, (item, mid))
        result["fishing"].setdefault(item, []).append({"mapID": mid,
            "installs": v["installs"], "windows": v["reports"]})
    for (item, oid) in sorted(pools):
        v = votes(pools, (item, oid))
        result["poolItems"].setdefault(item, []).append({"objectId": oid,
            "name": best_name(object_names, oid), "installs": v["installs"],
            "windows": v["reports"]})
    # Pool places only if a fishing-loot record identifies that *object* as source.
    pool_ids = {oid for _, oid in pools}
    for oid in sorted(pool_ids):
        name = best_name(object_names, oid)
        if not name:
            continue
        spots = []
        for key in sorted(object_positions):
            if key[0] != oid:
                continue
            v = votes(object_positions, key)
            _, mid, gx, gy = key
            spots.append({"mapID": mid, "x": gx / 50, "y": gy / 50,
                          "installs": v["installs"]})
        result["schools"].append({"objectId": oid, "name": name, "spots": spots})
    # Add actual observed pool positions to the corresponding loot-source edges.
    schools_by_id = {school["objectId"]: school for school in result["schools"]}
    for edges in result["poolItems"].values():
        for edge in edges:
            school = schools_by_id.get(edge["objectId"])
            if school and school["spots"]:
                spot = sorted(school["spots"], key=lambda rec: -rec["installs"])[0]
                edge.update({"mapID": spot["mapID"], "x": spot["x"], "y": spot["y"]})
    # Only numeric recipe ids are mapped to catalog operations. A name without an
    # observed recipe id cannot silently become a known client spell.
    recipe_names = {}
    for (spell, product, name) in sorted(recipes):
        v = votes(recipes, (spell, product, name))
        existing = result["recipes"].get(spell)
        if not existing or v["installs"] > existing["installs"]:
            result["recipes"][spell] = {"productItemId": product,
                                        "name": name, "installs": v["installs"]}
            if name:
                recipe_names.setdefault(name.casefold(), set()).add(spell)
    # Also permit unique exact-name links to client-verified spells.
    catalog = json.loads((ROOT / "database" / "catalog.json").read_text(encoding="utf-8"))
    for entity in catalog.get("entities", []):
        if entity.get("type") == "spell" and not entity["name"].startswith(("Spell #", "Unresolved")):
            recipe_names.setdefault(entity["name"].casefold(), set()).add(entity["id"])
    for (name, npc) in sorted(trainers):
        spells = recipe_names.get(name.casefold(), set())
        if len(spells) != 1:
            continue
        spell = next(iter(spells))
        v = votes(trainers, (name, npc))
        result["trainers"].setdefault(spell, []).append({
            "npcId": npc, "installs": v["installs"]})
    return result


def diff_summary(before, after):
    """An absent relation in a new snapshot is NOT an in-game deletion."""
    sections = ("itemNames", "npcs", "vendorItems", "drops", "fishing",
                "poolItems", "schools", "recipes", "trainers")
    summary = {
        "previousSnapshot": before.get("meta", {}).get("sourceSha256"),
        "currentSnapshot": after["meta"]["sourceSha256"],
        "dataAsOf": after["meta"].get("dataAsOf"),
        "sections": {},
        "note": "missingFromSnapshot is NOT proof that a game entity was removed"
    }
    for section in sections:
        old, new = before.get(section, {}), after.get(section, {})
        if isinstance(old, list) or isinstance(new, list):
            old = {str(x.get("objectId", i)): x for i, x in enumerate(old)}
            new = {str(x.get("objectId", i)): x for i, x in enumerate(new)}
        a, b = set(old), set(new)
        summary["sections"][section] = {
            "added": len(b - a), "missingFromSnapshot": len(a - b),
            "changed": sum(old[k] != new[k] for k in a & b)}
    return summary


def lua_pack(result):
    return ("-- Data from Everloot (https://everloot.app), CC BY-SA 4.0.\n"
            "-- https://creativecommons.org/licenses/by-sa/4.0/\n"
            "-- GENERATED OFFLINE. No raw install IDs or account data included.\n"
            "-- Game file data is NOT included in this observed pack.\n"
            "local _, ns = ...\nns.data.everloot = " + lua(result) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--input", type=Path)
    source.add_argument("--fetch", action="store_true")
    parser.add_argument("--as-of", help="Corpus snapshot timestamp (for NDJSON input)")
    parser.add_argument("--source-url", default=API,
                        help="Canonical URL of the exact observed corpus used for this build")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    records, asof, digest = load_live() if args.fetch else load_file(args.input)
    if not records:
        raise ValueError("Empty input is not proof of an empty Forever database")
    if args.as_of:
        asof = args.as_of
    result = normalize(records, asof, digest)
    if not args.source_url.startswith("https://"):
        raise ValueError("Source URL must be HTTPS")
    result["meta"]["sourceUrl"] = args.source_url
    output = lua_pack(result)
    normalized = json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    if args.check:
        if not LUA.is_file() or LUA.read_text(encoding="utf-8") != output:
            raise ValueError("Everloot Lua pack is stale; regenerate from the same corpus")
        if not JSON.is_file() or JSON.read_text(encoding="utf-8") != normalized:
            raise ValueError("Everloot JSON pack is stale; regenerate from the same corpus")
    else:
        previous = json.loads(JSON.read_text(encoding="utf-8")) if JSON.is_file() else {}
        diff = diff_summary(previous, result)
        JSON.parent.mkdir(parents=True, exist_ok=True)
        JSON.write_text(normalized, encoding="utf-8")
        LUA.write_text(output, encoding="utf-8")
        DIFF.write_text(json.dumps(diff, indent=2, sort_keys=True) + "\\n",
                        encoding="utf-8")
    print("Everloot records:", len(records), "| observed items:", len(result["itemNames"]),
          "| vendors:", len(result["vendorItems"]), "| schools:", len(result["schools"]))
    print(CREDIT)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as error:
        print("Everloot import error:", error, file=sys.stderr)
        sys.exit(1)
