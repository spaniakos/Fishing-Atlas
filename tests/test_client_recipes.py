# SPDX-License-Identifier: GPL-3.0-or-later
import copy
import json
import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from rebuild_client_recipes import SOURCE, merge
from build_catalog import INPUT


class ClientRecipesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = json.loads(SOURCE.read_text(encoding="utf-8"))
        cls.base = json.loads(INPUT.read_text(encoding="utf-8"))

    def test_build_and_recipe_counts(self):
        self.assertEqual(cls_build(self.raw), 70888)
        self.assertEqual(sum(len(p["recipes"]) for p in self.raw["professions"]), 136)
        self.assertEqual(len(self.base["recipes"]), 136)

    def test_canonical_import_idempotent(self):
        self.assertEqual(merge(self.base, self.raw), self.base)

    def test_wrong_build_rejected(self):
        bad = copy.deepcopy(self.raw)
        bad["build"]["version"] = "1.60.1.70707"
        with self.assertRaisesRegex(ValueError, "build"):
            merge(self.base, bad)

    def test_nightfin_relationship(self):
        r = next(r for r in self.base["recipes"] if r["spellId"] == 18243)
        self.assertEqual(r["outputItemId"], 13931)
        self.assertEqual({i["itemId"] for i in r["ingredients"]}, {13759, 159})
        self.assertEqual(r["profession"], "Cooking")


def cls_build(raw):
    return raw["build"]["buildId"]


if __name__ == "__main__":
    unittest.main()
