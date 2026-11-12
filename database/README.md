# Canonical Fishing Atlas Database

This directory holds the human-editable source database (`catalog.json`). **Do not edit generated Lua files by hand.**

Target build: **WoW Forever 1.60.1.70888**, interface **16001**.

## Generate

```bash
python3 scripts/build_catalog.py
python3 scripts/build_catalog.py --check
python3 scripts/validate.py
```

CI rejects missing IDs, orphaned recipe references, duplicate typed IDs, invalid provenance, and generated output drift.

## Canonical identity

- Item: numeric `itemId`.
- Spell or crafting operation: numeric `spellId`.
- NPC: numeric `npcId`.
- Zone or map: appropriate numeric ID with namespace.
- Schools and user observations: source-aware identifiers distinct from item IDs.
- Names are labels, not identifiers.
- Recipe is a relationship between cooking spell, recipe scroll, output item, ingredients and skill level.

## Source and validation

Each record must carry source/build metadata. `reference` means cross-game Classic reference and **not validated in Forever**. A verified client definition does not prove server-side vendor inventory or pool spawn availability.

The initial seed is intentionally tiny. A full build-matched licensed import is still required before v0.8 can be described as complete. External datasets cannot be bulk copied merely because a website is public.

## Coverage policy

Count **total**, **verified**, **provisional**, and **missing relationships** separately. Never turn unknown locations, catch probabilities, or vendor stock into fabricated values.
