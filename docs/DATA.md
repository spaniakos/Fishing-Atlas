# Data model and provenance

The v0.1 foundation records **player positions** only. Coordinates are normalized to the currently returned map ID and are not claimed to locate fishing pools precisely.

## Observation fields
`id`, `mapID`, `x`, `y`, `label`, `source`, `precision`, `firstSeen`, `lastSeen`, `sightings`.

Data confidence classes planned: `verified`, `historical`, `community`, and `provisional`. A school may have a recorded location without being spawned now.

## Future migration and sync
Schema version and stable observation IDs will be expanded before sync. Future import/export will validate item and map IDs, record source attribution, and default to stripping character names.

No bulk Wowhead dumps or source from third-party addons may be committed without a suitable license and attribution. Forever-specific values must be validated in game.
