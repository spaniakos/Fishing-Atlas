#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Report real record counts and provenance; never count planned/unknown entries."""
import json
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[1]
raw = json.loads((root / "database" / "catalog.json").read_text(encoding="utf-8"))
entities = Counter(x["type"] for x in raw["entities"])
confidence = Counter(x["confidence"] for x in raw["entities"])
sources = Counter(s["source"] for x in raw["entities"] for s in x["provenance"])
report = {
    "targetBuild": raw["meta"]["target"]["version"],
    "targetInterface": raw["meta"]["target"]["interface"],
    "catalogStatus": raw["meta"]["status"],
    "entities": dict(sorted(entities.items())),
    "entitiesByConfidence": dict(sorted(confidence.items())),
    "recipes": len(raw["recipes"]),
    "vendors": len(raw["vendors"]),
    "schools": len(raw["schools"]),
    "zones": len(raw["zones"]),
    "equipment": len(raw["equipment"]),
    "observations": len(raw["observations"]),
    "sources": dict(sorted(sources.items())),
    "verifiedForeverEntities": sum(
        any(s["verifiedInForever"] for s in x["provenance"])
        for x in raw["entities"]
    ),
}
print(json.dumps(report, indent=2, sort_keys=True))
