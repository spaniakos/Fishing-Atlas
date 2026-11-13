# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from package import build


class PackageTests(unittest.TestCase):
    def test_deterministic_installable_zip(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            first, digest = build(base / "one", "ci")
            second, digest2 = build(base / "two", "ci")
            self.assertEqual(digest, digest2)
            self.assertEqual(hashlib.sha256(first.read_bytes()).hexdigest(), digest)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as zipped:
                files = zipped.namelist()
                self.assertIn("FishingAtlas/FishingAtlas.toc", files)
                self.assertIn("FishingAtlas/LICENSE", files)
                self.assertIn("FishingAtlas/Data/Catalog.lua", files)
                self.assertTrue(all(p.startswith("FishingAtlas/") for p in files))
                self.assertTrue(all(not p.endswith(".pyc") for p in files))

    def test_current_version_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            artifact, _ = build(Path(tmp), "v0.99.1")
            self.assertTrue(artifact.is_file())

    def test_reject_mismatched_tag(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "Tag must match"):
                build(Path(tmp), "v9.9.9")

    def test_reject_unsafe_tag(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "Unsafe"):
                build(Path(tmp), "../bad")


if __name__ == "__main__":
    unittest.main()
