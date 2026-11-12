# Fishing Atlas

**A fishing encyclopedia and discovery atlas for World of Warcraft: Forever.**

[![CI](https://github.com/spaniakos/Fishing-Atlas/actions/workflows/ci.yml/badge.svg)](https://github.com/spaniakos/Fishing-Atlas/actions/workflows/ci.yml)
[![License: GPL v3+](https://img.shields.io/badge/License-GPLv3%2B-blue.svg)](LICENSE)

> Early development (0.1.0). Data is deliberately small and labeled as reference data until validated in the Forever client.

## Features in the first foundation
- `/fa` or `/fishingatlas`: command help; `/fa list` shows guide entries.
- `/fa add [label]`: record the **player's** current map position as a fishing observation.
- `/fa nearby`: list observations in the current map; these are **historical** sightings, not currently active pools.
- `/fa stats`: show the number of stored observations.
- `/fa notify on|off`: enable or disable zone-entry notices.
- Account-wide SavedVariables with migration-ready schema and coordinate clustering.
- Optional TomTom integration via `/fa waypoint` for your most recent observation.

## Installation
Copy the `FishingAtlas` folder into `World of Warcraft/_forever_/Interface/AddOns/` (adjust the client installation folder if different). Enable the addon and enter `/fa`.

The TOC targets interface `16001`. Verify the interface number on your Forever installation; this client is evolving.

## Safety and limitations
A location is an observation of a **player standing near water**, not proof a fish school is at exactly that coordinate. The addon never claims that a saved school is currently spawned. It does **not** automatically cast, hook, or loot fish in this first release. Protected game actions, if added later, will be initiated by player input and tested against Forever's restrictions.

## Roadmap
- v0.2: guarded one-key fishing assistant, gear/lure profiles, client API smoke tests
- v0.3: world-map/minimap markers, school recognition, proximity alerts, TomTom
- v0.4: validated fish/recipe/vendor encyclopedia and Fish-to-Table planning
- v0.5: fishing journal, collections, catch statistics
- v1.0: complete documentation, data provenance, translations, performance testing
- v2.0: optional companion sync with explicit user consent

See [ROADMAP.md](ROADMAP.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [docs/DATA.md](docs/DATA.md).

## License
Copyright (c) 2026 Georgios Spanos and contributors.
Licensed under **GNU GPL-3.0-or-later**. See [LICENSE](LICENSE). External game assets/data must have their own valid usage rights.
