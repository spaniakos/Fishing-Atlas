# WoW Forever build baseline

## Reference client

- Product: World of Warcraft: Forever
- Client version: `1.60.1.70888`
- Build date reported by player: `2026-11-09`
- Interface number: `16001`
- Source: player-reported `GetBuildInfo()` result, 2026-11-12

## Data acceptance rules

1. Prefer exports explicitly marked as client build `1.60.1.70888`.
2. For data from different builds, preserve its source build and label any discrepancies; do not silently upgrade its verification status.
3. Treat client-extracted item/spell/NPC identifiers separately from server-side availability, NPC vendor stock, school coordinates, and catch probabilities.
4. Historical Classic or Wowhead references remain provisional until checked against Forever.
5. Do not ingest or redistribute database exports without confirming their license or obtaining permission.
6. CI validates schema, referential integrity, and generated Lua structure; only in-game tests can establish live-client behavior.

## Next database work

Create canonical records for items (fish, poles, bait, lures, food), spells, recipes, NPCs, vendors, zones, fishing schools and observations. Link entities by numeric IDs, carry provenance on each relationship, and generate compact Lua bundles for offline use. Produce a coverage report identifying missing IDs, recipes, vendor links and unverified locations.
