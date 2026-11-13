#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Create deterministic, installable addon ZIP and SHA256 checksums.

Only bundled addon files plus GPL license and attribution metadata are shipped.
The archive has a top-level FishingAtlas directory suitable for Interface/AddOns.
"""
import argparse
import hashlib
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "FishingAtlas"
FIXED_TIME = (2026, 1, 1, 0, 0, 0)


def build(output_dir, tag):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,80}", tag):
        raise ValueError("Unsafe package tag")
    toc = (ADDON / "FishingAtlas.toc").read_text(encoding="utf-8")
    match = re.search(r"^## Version: (\d+\.\d+\.\d+)$", toc, re.MULTILINE)
    if not match:
        raise ValueError("Missing valid TOC version")
    if tag.startswith("v") and re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        if tag[1:] != match.group(1):
            raise ValueError("Tag must match TOC version")
    files = sorted(p for p in ADDON.rglob("*") if p.is_file() and p.suffix in {".toc", ".lua", ".tga"})
    if not any(p.name == "FishingAtlas.toc" for p in files):
        raise ValueError("Addon manifest missing")
    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / ("FishingAtlas-" + tag + ".zip")
    contents = [(p.relative_to(ROOT).as_posix(), p.read_bytes()) for p in files]
    contents.append(("FishingAtlas/LICENSE", (ROOT / "LICENSE").read_bytes()))
    contents.append(("FishingAtlas/DATA-LICENSES.txt", (ADDON / "DATA-LICENSES.txt").read_bytes()))
    contents.sort(key=lambda item: item[0])
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for path, raw in contents:
            entry = zipfile.ZipInfo(path, FIXED_TIME)
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = 0o100644 << 16
            z.writestr(entry, raw, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    sums = output_dir / "SHA256SUMS"
    sums.write_text(digest + "  " + destination.name + "\n", encoding="utf-8")
    return destination, digest


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument("--tag", default="ci")
    cli.add_argument("--output", type=Path, default=ROOT / "dist")
    args = cli.parse_args()
    zip_path, digest = build(args.output, args.tag)
    print("Packaged %s sha256=%s" % (zip_path, digest))


if __name__ == "__main__":
    main()
