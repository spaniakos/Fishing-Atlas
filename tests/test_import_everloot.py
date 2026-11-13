# SPDX-License-Identifier: GPL-3.0-or-later
"""Contract tests for Everloot's documented public record shapes."""
import hashlib
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from import_everloot import normalize, lua_pack  # noqa: E402
from build_catalog import lua  # noqa: E402


class EverlootImportTest(unittest.TestCase):
    def source(self):
        rows = []
        for i in range(1, 4):
            base = {"installId": "pub-" + str(i).zfill(32),
                    "capturedAt": "2026-11-12T10:00:00.000Z"}
            rows.append({**base, "eventId": "item:%d" % i, "kind": "item_seen",
                         "itemId": 6303, "name": "Raw Slitherskin Mackerel", "quality": "common"})
            rows.append({**base, "eventId": "vendor:%d" % i, "kind": "vendor",
                         "vendorNpcId": 1, "items": [{"itemId": 6256, "priceCopper": 23}]})
            rows.append({**base, "eventId": "npc:%d" % i, "kind": "npc_sighting",
                         "npcId": 1, "name": "Fishing Merchant", "mapId": 1411,
                         "x": 51, "y": 25, "positionKind": "interaction"})
            rows.append({**base, "eventId": "loot:%d" % i, "kind": "loot",
                         "lootType": "fishing", "sourceObjectId": 101,
                         "gatherKind": "fishing", "mapId": 1411, "x": 50, "y": 25,
                         "items": [{"itemId": 6303, "count": 1}]})
            rows.append({**base, "eventId": "object:%d" % i, "kind": "object_sighting",
                         "objectId": 101, "name": "Watery Fishing School",
                         "mapId": 1411, "x": 60, "y": 50})
            rows.append({**base, "eventId": "recipe:%d" % i, "kind": "recipe_observed",
                         "profession": "Cooking", "rank": 1, "recipe": "Test Fish",
                         "recipeId": 3371, "productItemId": 6303,
                         "difficulty": "optimal", "reagents": []})
            rows.append({**base, "eventId": "trainer:%d" % i, "kind": "trainer_seen",
                         "profession": "Cooking", "recipe": "Test Fish",
                         "requiredRank": 1, "trainerNpcId": 1})
        rows.append({**rows[0]})  # Duplicate event must not count twice.
        rows.append({"kind": "vendor", "installId": "missing", "vendorNpcId": 2,
                     "items": [{"itemId": 6256, "priceCopper": 50}]})
        return rows

    def test_three_independent_installs_and_provenance(self):
        out = normalize(self.source(), "2026-11-12T12:00:00Z", "sha-fixture")
        self.assertEqual(out["itemNames"][6303]["name"], "Raw Slitherskin Mackerel")
        self.assertEqual(out["vendorItems"][6256][0]["installs"], 3)
        self.assertEqual(out["vendorItems"][6256][0]["reports"], 3)
        self.assertEqual(out["fishing"][6303][0]["mapID"], 1411)
        self.assertEqual(out["poolItems"][6303][0]["objectId"], 101)
        self.assertEqual(out["schools"][0]["spots"][0]["x"], 0.6)
        self.assertEqual(out["trainers"][3371][0]["npcId"], 1)
        self.assertTrue(out["npcs"][1]["spots"][0]["near"])
        self.assertIn("CC BY-SA 4.0", out["meta"]["credit"])
        serialized = json.dumps(out)
        self.assertNotIn("pub-000", serialized)
        self.assertNotIn("eventId", serialized)
        self.assertIn("ns.data.everloot", lua_pack(out))

    def test_one_install_is_provisional_and_not_a_name(self):
        first = [r for r in self.source() if r.get("installId") == "pub-" + str(1).zfill(32)]
        out = normalize(first, None, "only-one")
        self.assertNotIn(6303, out["itemNames"])
        self.assertEqual(out["vendorItems"][6256][0]["installs"], 1)

    def test_avoid_classic_or_player_spot_inference(self):
        rows = [{**r, "kind": r["kind"]} for r in self.source()]
        for r in rows:
            if r.get("kind") == "object_sighting":
                r["objectId"] = 999
        out = normalize(rows, None, "no-pool-spawn")
        self.assertEqual(out["schools"], [])
        self.assertEqual(out["poolItems"][6303][0]["objectId"], 101)
        self.assertNotIn("mapID", out["poolItems"][6303][0])
        self.assertNotIn("installId", lua_pack(out))

    def test_numeric_lua_keys(self):
        self.assertIn("[6256]", lua({6256: [{"npcId": 10}]}))


if __name__ == "__main__":
    unittest.main()
