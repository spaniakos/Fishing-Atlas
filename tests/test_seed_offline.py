# SPDX-License-Identifier: GPL-3.0-or-later
"""Guard bootstrap imports against malformed/corrupt upstream manifests."""
import hashlib
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from seed_offline import CREDIT, NoBulkData, latest_index_path, select_corpus  # noqa: E402


class OfflineSeedTest(unittest.TestCase):
    def index(self):
        return {"credit": CREDIT, "dataAsOf": "2026-11-13T10:00:00Z",
                "files": [{"name": "corpus.ndjson", "dataset": "corpus",
                           "data": "observed", "rows": 3, "bytes": 120,
                           "sha256": hashlib.sha256(b"corpus").hexdigest()}]}

    def test_immutable_timestamp_pointer(self):
        stamp = "2026-11-13T10-20-30-000Z"
        self.assertEqual(latest_index_path(
            {"stamp": stamp, "index": stamp + "/index.json"}), stamp + "/index.json")
        with self.assertRaises(ValueError):
            latest_index_path({"stamp": stamp, "index": "../private/index.json"})
        with self.assertRaises(ValueError):
            latest_index_path({"stamp": "bad", "index": "bad/index.json"})

    def test_accept_only_licensed_observed_corpus(self):
        self.assertEqual(select_corpus(self.index())["rows"], 3)
        invalid = self.index()
        invalid["files"][0]["data"] = "game-files"
        with self.assertRaises(ValueError):
            select_corpus(invalid)
        invalid = self.index()
        invalid["files"][0]["sha256"] = "oops"
        with self.assertRaises(ValueError):
            select_corpus(invalid)
        invalid = self.index()
        invalid["dataAsOf"] = None
        with self.assertRaises(ValueError):
            select_corpus(invalid)
        invalid = self.index()
        invalid["files"][0]["rows"] = 0
        invalid["files"][0]["bytes"] = 0
        with self.assertRaises(NoBulkData):
            select_corpus(invalid)


if __name__ == "__main__":
    unittest.main()
