#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""No third-party dependencies. Verify release manifest and local data invariants."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
toc = root / "FishingAtlas" / "FishingAtlas.toc"
assert toc.exists()
body = toc.read_text(encoding="utf-8")
assert "## Interface: 16001" in body
assert "## SavedVariables: FishingAtlasDB" in body
assert "GPL-3.0-or-later" in body
files = [ln.strip() for ln in body.splitlines() if ln.strip() and not ln.startswith("##")]
assert files and len(files) == len(set(files))
for entry in files:
    assert (toc.parent / entry).is_file(), f"Missing TOC file: {entry}"
    assert ".." not in Path(entry).parts
assert (root / "LICENSE").is_file()
assert (root / "README.md").is_file()
assert (root / "ROADMAP.md").is_file()
m = re.search(r"## Version: (\d+\.\d+\.\d+)", body)
assert m, "Missing TOC version"
namespace = (root / "FishingAtlas" / "Core" / "Namespace.lua").read_text(encoding="utf-8")
assert f'ns.version = "{m.group(1)}"' in namespace, "Namespace and TOC version disagree"
print(f"manifest validated: {len(files)} Lua files")
