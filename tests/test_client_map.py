# SPDX-License-Identifier: GPL-3.0-or-later
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "database/catalog.json"
SOURCE = ROOT / "database/sources/client-map-zones-70888.json"


class MapTests(unittest.TestCase):
    def test_client_zone_import(self):
        raw = json.loads(SOURCE.read_text(encoding="utf-8"))
        cat = json.loads(CATALOG.read_text(encoding="utf-8"))
        self.assertEqual(raw["build"]["buildId"], 70888)
        self.assertEqual(len(raw["zones"]), 46)
        self.assertEqual(len(cat["zones"]), 46)
        zone_ids = {z["mapId"] for z in cat["zones"]}
        self.assertEqual(len(zone_ids), 46)
        self.assertIn(1411, zone_ids)
        for zone in cat["zones"]:
            self.assertTrue(all(k in zone["bounds"] for k in ("left", "top", "right", "bottom")))
            self.assertEqual(zone["confidence"], "verified_client")
            self.assertFalse(zone["provenance"][0]["verifiedInForever"])


if __name__ == "__main__":
    unittest.main()
