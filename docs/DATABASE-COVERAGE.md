# Fishing Atlas database coverage: v0.8 baseline

Target: WoW Forever `1.60.1.70888`, interface `16001`.

## Included offline content

| Content | Count | Evidence | Limitation |
| --- | ---: | --- | --- |
| Cooking spell/reagent recipes | 133 | Extracted Forever client files | Not confirmed obtainable in-game |
| Fishing craft spells | 3 | Extracted Forever client files | Not confirmed obtainable in-game |
| Zone maps and geometry | 46 | Extracted Forever client files | Not evidence of fishing pools |
| Named reference fish | 23 | Classic item-ID references | Live Forever drops unconfirmed |
| Poles and lures | 11 | Classic item-ID references | Stock/acquisition unconfirmed |
| All typed catalog entities | 449 | Mixed sources | Many unresolved item/spell names |
| Confirmed school spawn coordinates | 0 | No build-matched observation export | Stored player locations are **not** school spawns |
| Confirmed live vendor locations | 0 | No verified ingestion | In-game merchant scans begin accumulating local observations |
| Independently verified player-observed records | 0 | No player exports imported | Game file presence != live spawn |

## Supported user actions

- `/fa fish`, `/fa gear`, `/fa zones`, `/fa catalog`, `/fa find <term>`.
- `/fa recipeid <spellID>` resolves reagent and output IDs and attempts client API names.
- Merchant UI inventory scans capture local NPC/item ID observations.
- Player fishing positions and catch journal persist across characters.

## Coverage policy and completion boundary

This is a **usable initial atlas snapshot**, not an exhaustive live-game database.
Further content imports and verified spawn/vender observations remain work for ongoing
data updates and the later discovery systems. No fishing-school coordinates, vendor
stock, quest acquisition or catch probabilities have been invented.

An offline reference entry carries a `reference` status even if its item ID is
present in Classic. Client-extracted recipe entries carry `verified_client` but
are not marked `verified_ingame`.

The pre-v1 release candidate can include this curated but partial content as long
as coverage is disclosed and missing facts are not advertised as verified.


## v0.99.6 observed/source ingestion status

The 0.99.6 source graph and client export pipeline are implemented, **but neither a complete Everloot observed corpus nor a matching full open game-file export has been imported into this branch**. The bundled `EverlootObserved.lua` and `EverlootGameFiles.lua` contain explicit empty placeholders. They do **not** show that zero schools or sellers exist on Forever.

The current static base remains 136 build-70888 Cooking/Fishing recipe relationships, 46 map entries, 23 reference fish, 12 Classic school-type names, 96 mixed-reference vendors and 11 poles/lures. Those are not new independently confirmed sightings.

Once a full source is available, `scripts/import_everloot.py` generates normalized CC BY-SA observation data with distinct-install support, a source checksum and a last-diff report. The separate `scripts/import_everloot_gamefiles.py` filters build-70888 client metadata and marks it unconfirmed. This page must be regenerated with *real* counts before advertising complete coverage.
