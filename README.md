# Fishing Atlas

**A fishing encyclopedia and discovery atlas for World of Warcraft: Forever.**

[![CI](https://github.com/spaniakos/Fishing-Atlas/actions/workflows/ci.yml/badge.svg)](https://github.com/spaniakos/Fishing-Atlas/actions/workflows/ci.yml)
[![License: GPL v3+](https://img.shields.io/badge/License-GPLv3%2B-blue.svg)](LICENSE)

> **v0.99 pre-v1 candidate:** built for Forever 1.60.1.70888/interface 16001, with automated CI coverage. **Client-side acceptance testing remains pending**; full school-spawn/vendor datasets are incomplete.

## Existing features and in-progress database
- `/fa` or `/fishingatlas`: command help; `/fa list` shows guide entries.
- `/fa add [label]`: record the **player's** current map position as a fishing observation.
- `/fa nearby`: list observations in the current map; these are **historical** sightings, not currently active pools.
- `/fa stats`: show the number of stored observations.
- `/fa notify on|off`: enable or disable zone-entry notices.
- Account-wide SavedVariables with migration-ready schema and coordinate clustering.
- Optional TomTom integration via `/fa waypoint` for your most recent observation.

## v0.8 initial database
- 133 Cooking and 3 Fishing craft recipes from a build-70888 client extraction, with numeric relationships and provenance.
- `/fa catalog` reports imported counts; `/fa recipeid 18243` displays Nightfin Soup recipe relationships.
- `/fa find <term>` searches imported records; `/fa fish`, `/fa gear` and `/fa zones` browse categories.
- Client API name resolution where available; unresolved IDs remain explicitly labeled.
- Merchant-window item ID observations saved account-wide.
- **Not complete:** fishing-school coordinates, vendor guides, equipment acquisition locations and full acquisition paths remain outstanding. 23 reference fish and 11 gear IDs are indexed.

## v0.99 Explorer
Type `/fa` to open the compact UI. Tabs: fish, gear, recipes, zones, journal, schools and vendors. Search by name/ID. `/fa plan 18243 2` calculates missing Nightfin Soup ingredients against your bags. Live game-client UI compatibility is still pending player testing.

## Installation
Follow [the step-by-step installation guide](docs/INSTALLATION.md). The CI pipeline generates a reproducible addon ZIP (including the GPL license and SHA256SUMS) for `main`.
Copy the `FishingAtlas` folder into `World of Warcraft/_forever_/Interface/AddOns/` (adjust the client installation folder if different). Enable the addon and enter `/fa`.

The TOC targets interface `16001`. Verify the interface number on your Forever installation; this client is evolving.

## Safety and limitations
A location is an observation of a **player standing near water**, not proof a fish school is at exactly that coordinate. The addon never claims that a saved school is currently spawned. The optional Space override casts Fishing through a secure button when supported; hook and loot interactions remain manual and **not yet tested in-game**. Protected game actions, if added later, will be initiated by player input and tested against Forever's restrictions.

## Database baseline

The ID-based catalog lives at `database/catalog.json`, targets Forever build `1.60.1.70888`, and is generated with `python3 scripts/build_catalog.py`. Run `python3 scripts/catalog_coverage.py` for explicit record counts and provenance; the catalog contains extracted recipes/maps and selected reference fish/gear IDs but **is not an exhaustive Forever database**; see [coverage](docs/DATABASE-COVERAGE.md). See [ROADMAP.md](ROADMAP.md).

## Acceptance testing
See [the 12-case manual test plan](docs/ACCEPTANCE-v0.99.md), [test results](docs/TEST-RESULTS-v0.99.md), and [candidate notes](docs/RELEASE-v0.99.md). Do not treat automated CI as a substitute for in-game verification.

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

## v0.99.1 UI improvements
- Draggable minimap fishing icon: left-click explorer, right-click settings.
- Settings > AddOns > Fishing Atlas: minimap launcher, map markers, proximity alerts.
- Browser item/recipe icons from the game client, hover tooltips, larger click targets and Options shortcut.
- Tooltips and client textures are capability-dependent; report unsupported APIs during acceptance.

## v0.99.2 feedback: atlas UI
- Mousewheel/scrollbar replaces recipe pagination; two-pane explorer and larger item artwork.
- Category list has a selection inspector with sourced relationships.
- School tab now includes a **small, named Classic reference taxonomy** plus the player's observations; it is not a complete build-verified school database.
- Zones show school sightings and saved fishing positions when observed, not imaginary spawn tables.
- Vendors show recorded merchant inventories; the offline vendor directory remains incomplete.
- Right-click a school/zone with recorded coordinates to create a TomTom waypoint. No coordinate means the action is disabled.
- Notifications and map-pin toggles display their actual saved on/off state.

### Zone fishing skills and vendor reference labels
Zone details now show the minimum and reliable-catch Fishing skill using the [Wowhead Forever Fishing guide](https://www.wowhead.com/forever/guide/professions/fishing/overview-leveling), with special-water caveats. Unknown zones remain unknown. Reference vendor names, areas and starter fishing supplies come from [WoW Professions Forever](https://www.wow-professions.com/forever/how-to-fish). These are not confirmed live inventory snapshots; your client can record merchant item IDs and player coordinates on visiting a merchant. TomTom is available only for actual observed coordinates.

Zone details also show a **selected, reference-only list** of indicative fish from Classic-baseline Forever guides. It does not constitute a complete or live-verified spawn table. Sources: [The Forever Tavern](https://theforevertavern.com/professions/fishing) and [Icy Veins Forever](https://www.icy-veins.com/wow-forever/fishing/).

## v0.99.3 provenance-backed references
Fishing-related vendor NPCs, inventory candidates and map locations are now sourced from Finddon, with required ForeverDB.net attribution. Fish-by-zone and skill brackets come from Luredon with Classic/observed distinctions. These are **indexed, license-tracked reference records**, not 100% live-verified facts. See [source audit](docs/SOURCED-DATABASE-v0.99.3.md).


## Artwork and support (v0.99.4)
- The addon now includes original Fishing Atlas **TGA artwork**: compass/fish emblem, lakeshore header, deep-water panel background and bronze-blue buttons. [Artwork documentation](docs/ARTWORK.md).
- In the explorer click **Report issue**, or enter `/fa issue`. A selectable link to GitHub opens for copying (WoW cannot reliably launch a browser).
- [Submit a bug or feature request on GitHub](https://github.com/spaniakos/Fishing-Atlas/issues/new/choose).
- [Browse open issues](https://github.com/spaniakos/Fishing-Atlas/issues).

## v0.99.5 | Image-3 atlas explorer
The Explorer was redesigned around the third approved concept: branded panorama header, icon navigation, category sidebar, search/filters, sorted record list, dedicated section inspector, native zone map-art preview (when the Forever client exposes C_Map map layers), source-marked points, quick zone skill information and contextual vendor/fish links. Layout auto-scales to the available game viewport. The pictured concept's illustrative fish/school counts and "verified" flags are **not** treated as proof of live spawns. The actual client UI still requires acceptance testing.

## v0.99.6 offline data integration (in development)
Fishing Atlas can optionally consult separately installed [LibItemDB](https://www.curseforge.com/wow/addons/libitemdb) for cache-cold item names and links, and [LibProfessionDB](https://www.curseforge.com/wow/addons/libprofessiondb) for supplementary recipe metadata, with guarded fallbacks. **Neither library is required.** The canonical client-recipe catalog remains authoritative for its build, and borrowed Vanilla recipe source fields are excluded completely. See [source decision](docs/OFFLINE-LIBRARIES-v0.99.6.md).
