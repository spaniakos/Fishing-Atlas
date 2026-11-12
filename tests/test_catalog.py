# SPDX-License-Identifier: GPL-3.0-or-later
import copy
import json
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import build_catalog as catalog


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(catalog.INPUT.read_text(encoding="utf-8"))

    def test_valid_seed(self):
        self.assertEqual(len(catalog.validate(copy.deepcopy(self.data))["recipes"]), 1)

    def test_deterministic(self):
        self.assertEqual(catalog.build(self.data), catalog.build(copy.deepcopy(self.data)))

    def test_duplicate_id(self):
        broken = copy.deepcopy(self.data)
        broken["entities"].append(copy.deepcopy(broken["entities"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            catalog.validate(broken)

    def test_orphaned_ingredient(self):
        broken = copy.deepcopy(self.data)
        broken["recipes"][0]["ingredients"][0]["itemId"] = 987654
        with self.assertRaisesRegex(ValueError, "Orphaned"):
            catalog.validate(broken)

    def test_missing_provenance(self):
        broken = copy.deepcopy(self.data)
        broken["entities"][0]["provenance"] = []
        with self.assertRaisesRegex(ValueError, "provenance"):
            catalog.validate(broken)

    def test_refuse_wrong_build(self):
        broken = copy.deepcopy(self.data)
        broken["meta"]["target"]["interface"] = 12345
        with self.assertRaisesRegex(ValueError, "baseline"):
            catalog.validate(broken)


if __name__ == "__main__":
    unittest.main()
