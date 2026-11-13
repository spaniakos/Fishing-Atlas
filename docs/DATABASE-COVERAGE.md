# Fishing Atlas database coverage: historical baseline and v0.99.6

Target: WoW Forever `1.60.1.70888`, interface `16001`.

## Historical v0.8 client and reference baseline

| Content | Count | Evidence | Limitation |
| --- | ---: | --- | --- |
| Cooking spell/reagent recipes | 133 | Extracted Forever client files | Not confirmed obtainable in-game |
| Fishing craft spells | 3 | Extracted Forever client files | Not confirmed obtainable in-game |
| Zone maps and geometry | 46 | Extracted Forever client files | Not evidence of fishing pools |
| Named reference fish | 23 | Classic item-ID references | Live Forever drops unconfirmed |
| Poles and lures | 11 | Classic item-ID references | Stock/acquisition unconfirmed |
| All typed catalog entities | 449 | Mixed sources | Many unresolved item/spell names |
| Historical catalog school spawn coordinates | 0 | No object observations in v0.8 base | Stored player locations are **not** school spawns |
| Historical catalog confirmed vendor locations | 0 | Reference locations only | Read newer observed source layer separately |
| Historical catalog observations | 0 | v0.8 baseline | Not the separate Everloot v0.99.6 observation pack |

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


## v0.99.6: full public observed corpus, offline snapshot

A complete public Everloot observation corpus was imported from the keyed corpus API and bundled into FishingAtlas/Data/EverlootObserved.lua. This is an **offline snapshot** with source attribution, not a live network dependency. Snapshot date: **2026-11-13T14:10:21.029Z**. Raw source SHA-256: **b70c4a280ba90e74eec66e3bbd4958aa1a4c1f7f0c9ce9fa96b0ae4897915ecd**. Total source events read: **60,550** including unrelated event categories.

| Indexed relationship/category | Count | Qualification |
| --- | ---: | --- |
| NPC IDs referenced | 2,747 | Not every NPC/name/location is independently confirmed |
| Independently corroborated item names | 96 | Names, not proof of availability |
| Item IDs with vendor-offer edges | 562 | Each edge has distinct-install evidence |
| Item IDs with NPC-drop edges | 1,115 | Each edge has distinct-install evidence |
| Item IDs with fishing-source edges | 27 | May include non-fish fishing loot |
| Item IDs with fishing-pool-source edges | 27 | Pool source edges require evidence review |
| Observed numeric recipe IDs | 1,380 | Recipe observation does not establish acquisition |
| Recipe IDs with trainer edges | 190 | Evidence may be provisional |
| Observed eligible school-object entries | 0 | No valid matching object positions in this snapshot |

All imported evidence is from the Everloot public corpus under **CC BY-SA 4.0** (https://everloot.app); install identifiers were removed. Only three independently corroborating installations justify observed_confirmed on a specific edge; weaker evidence is observed_provisional. Reference catalogs and client-derived facts retain their separate provenance.

The existing 136 client recipe definitions, 46 map records, 23 reference fish, 12 Classic school names, 96 Finddon mixed-reference vendors, and 11 gear records remain available offline. They are not automatically promoted to live verified facts.

**Still missing:** a separate build-matching full game-file export, eligible observed school-object locations, exhaustive client item names/icons, and actual WoW Forever client acceptance. An absent source relation remains **unknown** rather than zero or unavailable.

Refresh: scripts/seed_offline.py selects a checksum-verified immutable bulk file where available, otherwise a complete keyed API pagination snapshot. scripts/import_everloot.py generates the Lua with source SHA and snapshot date. Scheduled changes are proposed for review before packaging.
