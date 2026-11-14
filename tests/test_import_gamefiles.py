# SPDX-License-Identifier: GPL-3.0-or-later
"""Contract tests for the build-matched, rights-separated Everloot game-file adapter."""
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from import_everloot_gamefiles import build, game_lua  # noqa: E402


class GameFileImportTest(unittest.TestCase):
    def fixture(self, root, build_id="1.60.1.70888"):
        directory = root / "game-files"
        directory.mkdir(parents=True)
        source = {
            "recipes": [
                {"professionId": 185, "professionName": "Cooking",
                 "spellId": 3371, "itemId": 6303, "minRank": 1,
                 "yellowRank": 20, "greyRank": 40,
                 "reagents": [{"itemId": 6303, "count": 1}], "build": build_id},
                {"professionId": 197, "professionName": "Tailoring",
                 "spellId": 3908, "itemId": 10001, "minRank": 1,
                 "yellowRank": 20, "greyRank": 40,
                 "reagents": [{"itemId": 2589, "count": 1}], "build": build_id}],
            "item-categories": [
                {"itemId": 6303, "classId": 0, "subclassId": 5,
                 "inventoryType": 0, "quality": 1, "className": "Consumable",
                 "subclassName": "Food", "slot": None, "qualityName": "Common"}],
            "relations": [
                {"fromKind": "item", "fromId": 6303,
                 "rel": "created_by", "toKind": "spell", "toId": 3371,
                 "build": build_id}]
        }
        manifest = {"schema": "everloot.open-data/1",
                    "gameFiles": {"version": build_id}, "files": []}
        for name, rows in source.items():
            data = "".join(json.dumps(rec) + "\n" for rec in rows).encode("utf-8")
            path = directory / (name + ".ndjson")
            path.write_bytes(data)
            manifest["files"].append({
                "path": "game-files/" + path.name,
                "layer": "game-files", "sha256": hashlib.sha256(data).hexdigest()})
        (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    def test_build_matching_and_evidence(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            data = build(root)
            self.assertIn(3371, data["recipes"])
            self.assertNotIn(3908, data["recipes"])  # Scope is Cooking/Fishing.
            self.assertIn(6303, data["categories"])
            self.assertEqual(data["relations"][0]["rel"], "created_by")
            self.assertEqual(data["meta"]["status"], "game_files_unconfirmed")
            self.assertIn("Blizzard", game_lua(data))
            all_data = build(root, all_professions=True)
            self.assertIn(3908, all_data["recipes"])

    def test_wrong_build_is_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root, "1.60.1.70862")
            with self.assertRaisesRegex(ValueError, "Wrong client build"):
                build(root)

    def test_checksum_conflict_is_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            (root / "game-files" / "recipes.ndjson").write_text("{}\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                build(root)


if __name__ == "__main__":
    unittest.main()
