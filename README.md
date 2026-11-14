# Fishing Atlas

**A fishing encyclopedia and discovery atlas for World of Warcraft: Forever.**

[![CI](https://github.com/spaniakos/Fishing-Atlas/actions/workflows/ci.yml/badge.svg)](https://github.com/spaniakos/Fishing-Atlas/actions/workflows/ci.yml)
[![License: GPL v3+](https://img.shields.io/badge/License-GPLv3%2B-blue.svg)](LICENSE)

> **v0.99.7 pre-v1 candidate:** targets Forever 1.60.1.70888/interface 16001. Bundles a complete public Everloot observation corpus snapshot (2026-11-13T14:10:21.029Z) as offline Lua. Relevant build-70888 client catalogs are bundled separately; in-game acceptance remains outstanding; absence of observed evidence means unknown, not zero.

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


## Offline-first usage and data updates

**Everloot is NOT a player-side dependency.** The complete set of data that
FishingAtlas currently knows is bundled inside its installable ZIP. No player
needs Everloot installed, an API key or Internet access. See
[Offline data packs](docs/OFFLINE-DATA-PACKS.md).

The initial v0.99.6 bundle contains the existing client and reference catalog;
the Everloot observed layer has been populated from the complete public corpus via the keyed API. Snapshot 2026-11-13T14:10:21.029Z (60,550 public observations), independently labeled per edge. The separately credited build-70888 game-file pack is now populated with 136 Cooking/Fishing recipes, 1,854 item categories and 3,356 selected item-spell relations. Neither pack requires Everloot on the player's computer.

For future refreshed observation snapshots, the configured `EVERLOOT_API_KEY` repository secret is used by the offline build runner only. Keep the key out of source files and installable releases. The scheduled/dispatchable
`everloot-refresh.yml` builds a reviewed, versioned source-data PR with proper
CC BY-SA attribution. It will never silently replace released data.
The key is used only by the builder, never embedded in the addon.

## v0.99.6 | Linked explorer and evidence-based data pipeline

- The middle inspector has hoverable, clickable item and spell rows. Recipe outputs and ingredients can show native tooltips; clicking goods follows their item record.
- Every item record has **Vendors / Drops / Crafted / Map** sections. Sellers lead to vendor detail, source evidence is labelled `observed_confirmed` (3 independent installs), `observed_provisional`, `verified_client`, or an appropriately qualified reference.
- Recipes have **Sources** for observed trainers, recipe scroll sellers and eligible drops, separate from skill/reagent/client-file definitions. Missing acquisition is explicitly unknown.
- Schools show object sightings with zone names and coordinates **only when object positions are actually observed**; saved personal nearby coordinates are still distinct.
- Map thumbnails preserve the native map artwork aspect ratio when `C_Map` layers exist. Map pins and navigation now use recognizable icons rather than anonymous squares; optional TomTom is still capability-dependent.
- The minimap emblem is larger, with a centered ring and adaptive radius.
- The **Source link** action shows a selectable upstream URL and attribution; WoW itself does not open websites.
- `FishingAtlas/Data/EverlootObserved.lua`: separately licensed **CC BY-SA 4.0** observed-data pack.
- `FishingAtlas/Data/EverlootGameFiles.lua`: separate **Blizzard client-game-file** pack; its rows are build-specific and always `game_files_unconfirmed`.
- `FishingAtlas/DATA-LICENSES.txt` is included in the installable ZIP.

### Importing the open database

The repository now includes a nonempty, attributed Everloot public observation snapshot (2026-11-13T14:10:21.029Z). It is not an exhaustive game-file database. The matching client-game-file pack is also populated, but deliberately marked game_files_unconfirmed (Blizzard data, not the observed-data CC BY-SA license).

```sh
# Existing corpus.ndjson or a saved public API response (preferred for reproducibility)
python3 scripts/import_everloot.py --input /path/to/corpus.ndjson --write
# Or page the public API. Optional free key stays on the builder, never in game.
EVERLOOT_API_KEY=... python3 scripts/import_everloot.py --fetch --write
# Refresh the pinned, build-matched public client catalogs (separate game-file credit)
python3 scripts/import_everloot_client_git.py --write
# Alternative if Everloot publishes a validated open-data export folder
python3 scripts/import_everloot_gamefiles.py --export /path/to/everloot-open-export --write
python3 scripts/build_catalog.py --check
python3 -m unittest discover -s tests -p 'test_*.py'
```

Observed records from Everloot must remain credited: **Data from Everloot (https://everloot.app), CC BY-SA 4.0.** Their install identifiers never enter the shipped pack. The client-game-file export is © Blizzard Entertainment, Inc., **not** under Everloot's CC BY-SA data license. Do not treat its items, recipes, category metadata or relation edges as in-game availability.

A scheduled/dispatchable [data refresh workflow](.github/workflows/everloot-refresh.yml) generates a **review PR** for changed observations; it does not auto-publish unreviewed assertions. If an unauthenticated full harvest exceeds Everloot's limits, configure the repository's optional `EVERLOOT_API_KEY` secret, or supply the complete licensed bulk corpus manually. The game addon never needs a key or makes HTTP requests.

See [Everloot integration contract](docs/EVERLOOT-INTEGRATION.md), [database coverage](docs/DATABASE-COVERAGE.md) and [v0.99.6 client acceptance](docs/CLIENT-TESTING.md).
