# Offline library decision for Fishing Atlas v0.99.6

This is one component of the **single v0.99.6 release**, not a separate release.

## Optional runtime libraries

* [LibItemDB (MIT)](https://www.curseforge.com/wow/addons/libitemdb): current publisher lists a Forever-specific offline item set (23,596 items, 12 locales as of Oct 2026). GetName and GetLink may provide a name/link when the client cache is cold. The client API wins when it answers. The boolean return from `catalog.name` is **false** for offline library names: offline records do not establish live availability.
* [LibProfessionDB (MIT)](https://www.curseforge.com/wow/addons/libprofessiondb): publisher lists 2,511 Forever recipes across 10 professions, with client-derived recipe records and flagged Vanilla-borrowed sources. A guarded `catalog.professionRecord` reads **only Forever client-derived fields** after checking the library's `GetGameVersion() == 'Forever'` and its `GetBorrowed` metadata. Borrowed acquisition sources, hidden status and skill requirements are never surfaced; unmarked client-derived skill may be included. The library **does not overwrite** our client-recipe catalog.
* [CraftLib](https://www.curseforge.com/wow/addons/craftlib): currently Classic-specific; public listing says **All Rights Reserved**, not a Forever flavor. Do not vendor or scrape.
* [Questie-Forever](https://github.com/tysongoulding/Questie-Forever): inspect as a quest/NPC reference, preserving its license and provenance. Not a complete fishing-pool database.
* [ForeverDB](https://www.curseforge.com/wow/addons/foreverdb): player observations and source IDs where the publisher permits, not proof of every present-day spawn.

The libraries are **optional separately installed addons**. No third-party code or full data tables are bundled, and no mandatory `LibStub` dependency is introduced. The addon remains self-contained. Installed modules must expose their documented LibStub names and be ready. Failure is nonfatal.

## DB2 extraction is not a replacement for server verification

[WoWDBDefs](https://github.com/wowdev/WoWDBDefs) + [DBCD](https://github.com/wowdev/DBCD) or [wow.export](https://github.com/Kruithne/wow.export) can generate client-derived item/spell/recipe relations for a **pinned Forever build**. Capture extraction tool revision, build, license and table definitions. Server-side live vendor stock, drops and fishing-pool coordinates generally cannot be inferred from client DB2 presence. Do not mark them live-verified.

## Required source priority

1. Actual in-game recording (NPC GUID, item ID, zone, coordinates, build and time).
2. Build-identified Forever client data (existence and client-defined recipe relations, not availability).
3. Forever-targeted offline libraries, with borrowed fields hard-excluded (never ingested).
4. Licensed community reference tables (Finddon/Luredon/CMaNGOS/Questie), labeled as reference.
5. Unsupported or unlicensed sources: reject until reviewed.

## Release acceptance

- Missing optional libraries never prevent Fishing Atlas loading.
- Native client names have precedence over offline names.
- A borrowed Vanilla recipe source remains marked unverified.
- Reverse links (item -> vendor/drop/craft; recipe -> trainer/vendor/drop; school -> zone) require provenance per edge.
- Show source and build in an item-detail view before claiming verification.
- No fake TomTom coordinates or invented drops when relationships are absent.
