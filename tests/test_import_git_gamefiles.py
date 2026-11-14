# SPDX-License-Identifier: GPL-3.0-or-later
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from import_everloot_client_git import normalize, TARGET, NOTICE


class GitClientDataTest(unittest.TestCase):
    def fixtures(self):
        build = {"version": TARGET, "buildConfig": "same", "extractedAt": "2026-11-10"}
        rec = {"schema": "everloot.client-recipes/1", "credit": NOTICE,
               "build": dict(build), "professions": [
                   {"name": "Cooking", "recipes": [
                       [1 + x, 100 + x, 50, 75, 100, [[200, 2]]] for x in range(105)]},
                   {"name": "Tailoring", "recipes": [[999, 500, 1, 2, 3, [[300, 1]]]]}]}
        layer = {"schema": "everloot.client-layer/2", "credit": NOTICE,
                 "build": dict(build), "categories": {
                     "classes": [{"id": 0, "name": "Consumable"}],
                     "subclasses": [{"classId": 0, "id": 5, "name": "Food"}]},
                 "items": [[100, 0, 5, 0, 1], [200, 0, 5, 0, 1], [500, 0, 5, 0, 1]],
                 "edges": [["item", 100, "created_by", "spell", 1],
                           ["item", 200, "reagent_for", "spell", 1],
                           ["item", 500, "created_by", "spell", 999],
                           ["item", 100, "same_icon", "icon", 13]]}
        return rec, layer

    def test_matching_build_and_relevant_relationships(self):
        recipe, layer = self.fixtures()
        out = normalize(recipe, layer, {"entities": [{"type": "item", "id": 100}]},
                        {"vendorItems": {}, "drops": {}}, "c" * 40,
                        {"client-layer.json": "x" * 64})
        self.assertEqual(len(out["recipes"]), 105)
        self.assertEqual(out["categories"][100]["subclassName"], "Food")
        self.assertEqual(len(out["relations"]), 2)
        self.assertNotIn(999, out["recipes"])
        self.assertEqual(out["meta"]["status"], "game_files_unconfirmed")

    def test_reject_wrong_build_and_changed_credit(self):
        recipe, layer = self.fixtures()
        recipe["build"]["version"] = "1.60.1.99999"
        with self.assertRaisesRegex(ValueError, "build mismatch"):
            normalize(recipe, layer, {"entities": []}, {}, "c" * 40, {})
        recipe, layer = self.fixtures()
        layer["credit"] = "different"
        with self.assertRaisesRegex(ValueError, "credit changed"):
            normalize(recipe, layer, {"entities": []}, {}, "c" * 40, {})


if __name__ == "__main__":
    unittest.main()
