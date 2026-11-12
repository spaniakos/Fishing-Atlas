# SPDX-License-Identifier: GPL-3.0-or-later
import re
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]


class AcceptancePlanTests(unittest.TestCase):
    def test_12_groups_are_unique_and_unexecuted(self):
        plan = (ROOT / "docs/ACCEPTANCE-v0.99.md").read_text(encoding="utf-8")
        results = (ROOT / "docs/TEST-RESULTS-v0.99.md").read_text(encoding="utf-8")
        groups = re.findall(r"^## (T\d{2})", plan, re.MULTILINE)
        self.assertEqual(groups, ["T%02d" % i for i in range(1, 13)])
        for group in groups:
            self.assertIn("| " + group + " |", results)
        self.assertEqual(results.count("NOT TESTED |"), 12)

    def test_pre_v1_is_clear(self):
        notes = (ROOT / "docs/RELEASE-v0.99.md").read_text(encoding="utf-8")
        self.assertIn("not v1.0", notes)
        self.assertIn("NOT TESTED", notes)


if __name__ == "__main__":
    unittest.main()
