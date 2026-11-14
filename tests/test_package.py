# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from package import build, validate_observed_pack


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
                self.assertIn("FishingAtlas/DATA-LICENSES.txt", files)
                self.assertIn("FishingAtlas/Data/Catalog.lua", files)
                self.assertIn("FishingAtlas/Art/atlas-emblem.tga", files)
                self.assertIn("FishingAtlas/Art/deepwater-background.tga", files)
                self.assertIn("FishingAtlas/Art/lakeshore-banner.tga", files)
                self.assertIn("FishingAtlas/Art/bronze-button.tga", files)
                header = zipped.read("FishingAtlas/Art/atlas-emblem.tga")
                self.assertEqual(header[2], 2)
                self.assertEqual(header[16], 32)
                self.assertEqual(header[12] + 256 * header[13], 128)
                self.assertTrue(all(p.startswith("FishingAtlas/") for p in files))
                self.assertTrue(all(not p.endswith(".pyc") for p in files))

    def test_current_version_package(self):
        with tempfile.TemporaryDirectory() as tmp:
            toc = (ROOT / "FishingAtlas" / "FishingAtlas.toc").read_text()
            version = next(line.removeprefix("## Version: ").strip()
                           for line in toc.splitlines()
                           if line.startswith("## Version: "))
            artifact, _ = build(Path(tmp), "v" + version)
            self.assertTrue(artifact.is_file())

    def test_reject_missing_or_unattributed_offline_pack(self):
        with self.assertRaisesRegex(ValueError, "checksum-verified"):
            validate_observed_pack('sourceSha256 = "not-imported"')
        with self.assertRaisesRegex(ValueError, "attribution"):
            validate_observed_pack('sourceSha256 = "' + "a" * 64 +
                                   '" dataAsOf = "2026-11-13"')
        with self.assertRaisesRegex(ValueError, "timestamp"):
            validate_observed_pack('sourceSha256 = "' + "a" * 64 +
                                   '" Data from Everloot (https://everloot.app), CC BY-SA 4.0.')

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
