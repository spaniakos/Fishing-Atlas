# Development roadmap

## Milestone 0.1 — Foundation
- [x] GPL-3.0-or-later license and contributor documentation
- [x] Installable Lua 5.1 addon skeleton and slash commands
- [x] Schema-versioned observation storage and manual position capture
- [x] Unit tests, linting and manifest checks in GitHub Actions
- [ ] Verify with live WoW Forever interface 16001

## Milestone 0.2 — Fishing controls
- [ ] Probe protected action APIs in Forever
- [ ] Optional player-triggered one-key cast/interact mode, with original bindings restored
- [ ] Equipment / lure profile and combat handling
- [ ] In-game smoke-test checklist

## Milestone 0.3 — Atlas
- [ ] World-map and minimap pins
- [ ] Identified school encounter recorder (player position, not pool position)
- [ ] Alert radius and cooldowns with optional TomTom routing
- [ ] Distinguish inferred, historical, and personally verified sightings

## Milestone 0.4 — Encyclopedia & cooking
- [ ] Curated and provenance-labeled fish database
- [ ] Fish-to-recipe-to-cooked-food relationships
- [ ] NPC/vendor acquisition and navigation
- [ ] Fish-to-Table inventory-aware planner

## Milestone 0.5 — Collection and statistics
- [ ] Catch-event correlation and journal
- [ ] Collection catalog and session statistics
- [ ] Optional inventory integration

## Milestone 1.0 — Stable
- [ ] Documentation, localizations, client regression suite and optimized map data
- [ ] Release packaging and checksum artifacts
- [ ] Original graphics and accessibility review

## Milestone 2.0 — Community
- [ ] Opt-in export/import and companion sync, no unauthorized HTTP in the addon
- [ ] Server deduplication, privacy and provenance controls

Definition of Done: tested under Lua 5.1; client smoke-tested when interaction dependent; documented data provenance; no botting or automated protected inputs; CI green.
