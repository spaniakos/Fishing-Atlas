# SPDX-License-Identifier: GPL-3.0-or-later
import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from build_recipe_index import build


class RecipeIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads((ROOT / "database/catalog.json").read_text())
        cls.eg = json.loads((ROOT / "database/observed/eg-cooking.json").read_text())
        cls.refs = json.loads((ROOT / "database/sources/recipe-edges-v2.json").read_text())

    def test_identity_and_coverage(self):
        graph = build(self.catalog, self.eg, self.refs)
        self.assertEqual(graph["coverage"]["total"], 136)
        self.assertEqual(graph["coverage"]["teachingItemKnown"], 6)
        self.assertEqual(graph["coverage"]["learnRankKnown"], 14)
        records = {r["spellId"]: r for r in graph["records"]}
        self.assertEqual(len(records), 136)
        self.assertEqual(records[15935]["teachingItems"][0]["itemId"], 12226)
        self.assertEqual(records[15935]["skills"]["learn"]["rank"], 1)
        self.assertEqual(records[2541]["skills"]["learn"]["rank"], 50)
        self.assertEqual(records[2795]["skills"]["learn"]["rank"], 25)
        self.assertEqual(records[18243]["skills"]["grey"]["rank"], 330)
        self.assertIsNone(records[818]["skills"]["learn"])

    def test_no_name_based_join(self):
        refs = copy.deepcopy(self.refs)
        refs["edges"] = [e for e in refs["edges"] if e["spellId"] != 15935]
        graph = build(self.catalog, self.eg, refs)
        record = next(r for r in graph["records"] if r["spellId"] == 15935)
        self.assertEqual(record["teachingItems"], [])
        self.assertEqual(record["acquisitions"], [])
        self.assertIsNone(record["skills"]["learn"])

    def test_conflicting_trainer_rank_is_reported(self):
        eg = copy.deepcopy(self.eg)
        eg["trainers"]["2541"].append({
            "npcId": 999999, "name": "Test conflict",
            "skillRank": 500, "sourceBuild": "1.60.1.70938"})
        graph = build(self.catalog, eg, self.refs)
        conflicts = [c for c in graph["conflicts"] if c["spellId"] == 2541]
        self.assertTrue(conflicts)
        record = next(r for r in graph["records"] if r["spellId"] == 2541)
        self.assertIsNone(record["skills"]["learn"],
                          "Conflicting real trainer ranks must not be guessed")

    def test_duplicate_and_orphan_references_rejected(self):
        refs = copy.deepcopy(self.refs)
        refs["edges"].append(copy.deepcopy(refs["edges"][0]))
        with self.assertRaises(ValueError):
            build(self.catalog, self.eg, refs)
        refs = copy.deepcopy(self.refs)
        refs["edges"][0]["spellId"] = 9999999
        with self.assertRaises(ValueError):
            build(self.catalog, self.eg, refs)


if __name__ == "__main__":
    unittest.main()
