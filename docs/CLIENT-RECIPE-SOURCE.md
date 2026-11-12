# WoW Forever Cooking and Fishing client recipe extract

Reference build: **1.60.1.70888** (`2026-11-09`), interface `16001`.

Upstream: [Everloot client-recipes.json](https://github.com/Everloot/everloot/blob/374ec8362bbbbc4aac39082ffc0d7348e5746a7d/web/src/data/game-data/client-recipes.json), commit `374ec8362bbbbc4aac39082ffc0d7348e5746a7d`, extracted `2026-11-10T17:17:03.601Z`.

**Credit:** Game data © Blizzard Entertainment, Inc. Numeric relation extract published by Everloot; their extraction notes credit WoWDBDefs column definitions under CC BY-SA 4.0. This source is *game-file data*, not the CC BY-SA 4.0 player-observation corpus. No Everloot addon code or assets are included.

## Imported
- 133 Cooking recipes
- 3 Fishing craft recipes
- 275 ingredient references
- IDs, base output quantities, minimum skill, yellow/grey triviality limits and ingredient amounts

The extraction supplies no reliable localized names, recipe scroll item IDs or live vendor inventories for these records. Newly inferred item and spell identifiers are labeled `Item #ID` and `Spell #ID` until the game API or another build-matched source resolves names. Do not present these placeholders as actual item names.

## Not imported
- Fishing-school spawn coordinates and open-water drop probabilities
- Vendor inventories, locations, trainer offers, quests, live availability
- Client art files or any third-party addon implementation

Source data is preserved at `database/sources/client-recipes-70888.json`. Rebuild via `scripts/rebuild_client_recipes.py` after editing or updating the reviewed snapshot. CI ensures generated Lua matches the canonical JSON.

These records are **client-extracted, not live verified**.
