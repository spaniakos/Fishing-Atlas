# SPDX-License-Identifier: GPL-3.0-or-later
import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from import_curated import import_pack
from build_catalog import INPUT


class ImportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = json.loads(INPUT.read_text(encoding="utf-8"))
        cls.example = json.loads((ROOT / "database/source-pack.example.json").read_text(encoding="utf-8"))

    def test_empty_reviewed_source(self):
        output = import_pack(self.base, self.example)
        self.assertEqual(output, self.base)

    def test_refuse_unreviewed_pack(self):
        pack = copy.deepcopy(self.example)
        pack["meta"]["reviewed"] = False
        with self.assertRaisesRegex(ValueError, "review"):
            import_pack(self.base, pack)

    def test_refuse_bad_license(self):
        pack = copy.deepcopy(self.example)
        pack["meta"]["license"] = "unknown"
        with self.assertRaisesRegex(ValueError, "license"):
            import_pack(self.base, pack)

    def test_refuse_wrong_build(self):
        pack = copy.deepcopy(self.example)
        pack["meta"]["build"] = "1.60.1.70124"
        with self.assertRaisesRegex(ValueError, "target"):
            import_pack(self.base, pack)

    def test_new_record(self):
        pack = copy.deepcopy(self.example)
        pack["entities"] = [{
            "type": "item", "id": 999001, "name": "Test Fish",
            "category": "fish", "confidence": "provisional",
            "provenance": [{"source": "reviewed_test", "build": "1.60.1.70888",
                            "verifiedInForever": False}]
        }]
        result = import_pack(self.base, pack)
        self.assertEqual(len(result["entities"]), len(self.base["entities"]) + 1)
        self.assertEqual(len(self.base["entities"]), 5)

    def test_reject_duplicate(self):
        pack = copy.deepcopy(self.example)
        pack["entities"] = [copy.deepcopy(self.base["entities"][0])]
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            import_pack(self.base, pack)


if __name__ == "__main__":
    unittest.main()
