# Fishing Atlas v0.99.3 reference data provenance

**Important:** "indexed" != "verified in the Forever game." These are GPL-compatible source extracts with mixed provenance, not 100% confirmed gameplay data.

## Finddon: NPCs + merchant goods

Source [Finddon](https://github.com/WoW-Forever-Addons/finddon/tree/af6b8746c7735cf038a410c15b773487f4ac0b49), Data/NPCs.lua and Data/Goods.lua.

Pinned commit: `af6b8746c7735cf038a410c15b773487f4ac0b49`.

License: **GPLv3** for those generated datasets, plus [third-party notices](https://github.com/WoW-Forever-Addons/finddon/blob/main/THIRD_PARTY_LICENSES.txt).
**Required credit: Data from ForeverDB.net (https://foreverdb.net).** Source also includes CMaNGOS classic-db contributors, Forever client map assignments via All The Things, and Don player records.

Extraction: 96 fishing-related NPCs, including 23 fishing trainers and 75 known candidate sellers of basic fishing gear/lures/expert book. NPC positions were decoded from Finddon's base-36 map positions. Item lists are **not all confirmed current server stock**. Reference waypoints are labeled accordingly. This is not an all-professions vendor database.

## Luredon: fish by map + fishing skill

Source [Luredon](https://github.com/WoW-Forever-Addons/luredon/tree/46e79568b4f190867c46bd85c1c50ea6afe116f8), Data_Fish.lua, Data.lua.

Pinned commit: `46e79568b4f190867c46bd85c1c50ea6afe116f8`.

License: **GPLv3** for generated fish data, based on CMaNGOS classic-db plus recorded Luredon catches (with ATT map assignment data). This modified extract preserves evidence by record.

- 44 indexed zone-water fish lists, reference species only.
- Explicitly player-recorded Zephras Isle records; community-observed Teldrassil 6303.
- Drops the source's theoretical CMaNGOS percentages, avoiding false live drop-rate claims.
- 44 indexed classic-derived fishing zones. The source lists reliable skill; minimum follows published Forever fishing guide brackets.
- Zone-level water and sub-areas may differ.

## Evidence classes

- **client_70888**: item/spell/reagent names or relationships extracted from game files, without proving live server acquisition.
- **classic/cmangos_reference**: data mapped to Forever zone IDs, but not live-confirmed.
- **community_recorded**: caught/sighted by Luredon contributors. Independent user validation is still needed.
- **own_live_observed**: actual merchant/catch/school sighting recorded in current client. May become stale; requires coordinates/evidence.

Avoid using "verified in Forever" for either Classic references or client-file presence. Wowhead Forever, WCLBox and other guide pages can corroborate; they do not automatically establish current server spawns.

## Remaining gaps
Fishing school-specific spawn coordinates, comprehensive named school taxonomy, exact live vendor stock, trainer offers and fishing water subareas still require additional source validation or player captures. Do not claim full verification based on the source counts.
