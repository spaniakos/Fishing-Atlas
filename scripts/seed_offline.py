#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Seed the shipped offline pack from Everloot's bulk export or the public API.

No network access is required in WoW. This program runs on the release builder,
never on a player's machine. It refuses a missing or corrupt upstream snapshot.
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BASE = "https://data.everloot.app"
CREDIT = "Data from Everloot (https://everloot.app), CC BY-SA 4.0."
MAX_BYTES = 150 * 1024 * 1024
ROOT = Path(__file__).resolve().parents[1]


def get_bytes(url, limit=MAX_BYTES):
    req = Request(url, headers={"User-Agent": "FishingAtlas-offline-build/0.99.6"})
    with urlopen(req, timeout=60) as response:
        raw = response.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Upstream response exceeds safe size limit")
    return raw


def latest_index_path(pointer):
    """Reject cross-origin/path traversal pointers."""
    if not isinstance(pointer, dict):
        raise ValueError("Invalid Everloot latest.json")
    path = pointer.get("index")
    stamp = pointer.get("stamp")
    if not isinstance(path, str) or not isinstance(stamp, str):
        raise ValueError("Invalid Everloot bulk pointer")
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{3}Z", stamp):
        raise ValueError("Invalid Everloot bulk snapshot stamp")
    if path != stamp + "/index.json":
        raise ValueError("Bulk pointer must target its own immutable index")
    return path


def select_corpus(index):
    """The corpus must be the published observed-data file with a valid digest."""
    if not isinstance(index, dict):
        raise ValueError("Invalid bulk index")
    if index.get("credit") != CREDIT or index.get("dataAsOf") is None:
        raise ValueError("Bulk index lacks Everloot attribution or corpus snapshot date")
    files = index.get("files")
    if not isinstance(files, list):
        raise ValueError("Bulk index missing file manifest")
    entries = [f for f in files if isinstance(f, dict) and f.get("name") == "corpus.ndjson"]
    if len(entries) != 1:
        raise ValueError("Bulk export does not contain exactly one corpus.ndjson")
    item = entries[0]
    if item.get("data") != "observed" or item.get("dataset") != "corpus":
        raise ValueError("Bulk corpus has unexpected ownership or dataset")
    if not isinstance(item.get("sha256"), str) or not re.fullmatch(r"[a-fA-F0-9]{64}", item["sha256"]):
        raise ValueError("Bulk corpus SHA-256 missing/invalid")
    if not isinstance(item.get("bytes"), int) or not 0 < item["bytes"] <= MAX_BYTES:
        raise ValueError("Bulk corpus size missing/invalid")
    if not isinstance(item.get("rows"), int) or item["rows"] < 1:
        raise ValueError("Empty bulk corpus cannot seed verified offline content")
    return item


def bulk():
    pointer = json.loads(get_bytes(BASE + "/latest.json", 100_000))
    index_path = latest_index_path(pointer)
    index = json.loads(get_bytes(BASE + "/" + index_path, 1_000_000))
    item = select_corpus(index)
    url = BASE + "/" + pointer["stamp"] + "/corpus.ndjson"
    data = get_bytes(url)
    if len(data) != item["bytes"]:
        raise ValueError("Bulk corpus byte length does not match its immutable index")
    if hashlib.sha256(data).hexdigest().lower() != item["sha256"].lower():
        raise ValueError("Bulk corpus SHA-256 mismatch")
    if len([line for line in data.splitlines() if line.strip()]) != item["rows"]:
        raise ValueError("Bulk corpus row count mismatch")
    return data, index["dataAsOf"], url


def seed():
    # Prefer the immutable index plus checksum; the API is a documented
    # fallback when the bulk export has not been published yet.
    try:
        raw, asof, url = bulk()
        with tempfile.TemporaryDirectory(prefix="fishingatlas-everloot-") as tmp:
            corpus = Path(tmp) / "corpus.ndjson"
            corpus.write_bytes(raw)
            cmd = [sys.executable, str(ROOT / "scripts" / "import_everloot.py"),
                   "--input", str(corpus), "--as-of", asof, "--source-url", url, "--write"]
            subprocess.run(cmd, check=True, cwd=ROOT)
        print("Offline source: verified immutable Everloot bulk export", url)
        return
    except (HTTPError, URLError, TimeoutError) as exc:
        # The bulk endpoint may genuinely be unpublished. Attempt the API
        # rather than pretending a missing export is an empty data set.
        print("Bulk export unavailable; trying public corpus API:", str(exc), file=sys.stderr)
    # A malformed or corrupt published bulk file is fatal, NEVER a reason to
    # silently use a different source.
    subprocess.run([sys.executable, str(ROOT / "scripts" / "import_everloot.py"),
                    "--fetch", "--write"], check=True, cwd=ROOT)
    print("Offline source: Everloot public corpus API")


if __name__ == "__main__":
    try:
        seed()
    except (ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print("Offline seed FAILED; existing pack left unchanged:", exc, file=sys.stderr)
        sys.exit(1)
