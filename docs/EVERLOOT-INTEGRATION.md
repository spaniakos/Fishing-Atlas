# Everloot ingestion contract for Fishing Atlas

Status: v0.99.6 draft includes a complete public Everloot observation corpus snapshot imported 2026-11-13T14:10:21.029Z and shipped as attributed offline Lua. The relevant build-matched client game-file catalog has also been imported separately; actual WoW client acceptance remains pending. A complete observation corpus is **not** an exhaustive verified game database.

## Upstream
- Project: https://everloot.app/
- Public observation corpus: https://everloot.app/api/corpus/public
- Corpus documentation: https://everloot.app/docs/api/corpus-public
- Open export: https://everloot.app/database/download
- Bulk files: https://everloot.app/docs/api/data-files
- MCP reference (for lookups, not a WoW runtime API): https://everloot.app/docs/mcp
- License: https://everloot.app/docs/licence

**Required attribution for observed data:**
> Data from Everloot (https://everloot.app), CC BY-SA 4.0.

Observed contributor records are CC BY-SA 4.0. Game-file derived data is **not** covered by that license; it must carry its own Blizzard/source notice and an explicit unconfirmed game-build label. Do not assume copying an entire third-party dataset into a GPL add-on automatically satisfies CC BY-SA requirements. Keep data files, provenance and licensing notices distinct; review redistribution terms before any release.

## Collection constraints
- The WoW client cannot access HTTP. Fetch and normalize data **offline**, at build/release time.
- Public corpus endpoint supports `limit=500` without a key, with a shared rate limit stated as 30 requests/hour/IP. An optional free key permits larger pages (`limit=5000`) and higher throughput, but is not required by players.
- Follow `next` through to null. Compare `dataAsOf` on every page; if it changes, discard the incomplete run and restart.
- Treat HTTP 503 as unavailable, HTTP 429 as throttling; neither means zero observed records.
- Bulk `corpus.ndjson` is preferable for complete repeatable imports.
- Preserve retrieved snapshot date, schema, dataset URL, credit, source checksum and game-build indicators in an offline provenance manifest.
- Do not ship `installId`, `eventId`, player identities or other installation pseudonyms in the addon.

## Confidence rules
- Everloot's general player-observation confirmation policy requires **three distinct independent installs**, not merely three sightings. Represent lower-support records as provisional.
- Individual observations are evidence, not proof of a permanent vendor stock, NPC spawn, fish drop rate, or school availability.
- Fishing windows can use `lootType: "fishing"`. Do **not** infer fishing catches from all loot windows or confuse fishing with skinning/gathering.
- School coordinates must distinguish *actual observed object location* from Fishing Atlas's historical *player proximity* observations. Never convert proximity into a precise pool spawn.
- Preserve `gameData` entries separately from the CC BY-SA observation corpus; game-file metadata is **unconfirmed** and build-specific.
- A missing record is **unknown**, not a zero probability or proof of unobtainability.

## Implemented generated datasets and actions

1. `scripts/import_everloot.py` reads a complete public API/NDJSON corpus, checks paging snapshots, counts independent installs, removes install IDs and writes `FishingAtlas/Data/EverlootObserved.lua`, `database/observed/everloot-normalized.json` and `database/observed/last-diff.json`. The live addon reads it with `FishingAtlas/Data/ObservedRuntime.lua`.
2. `scripts/import_everloot_client_git.py` imports the build-70888 client-recipes and client-layer catalogs from an immutable Everloot Git revision with source digests, emitting `FishingAtlas/Data/EverlootGameFiles.lua` and a separate JSON manifest. The alternative `scripts/import_everloot_gamefiles.py` accepts a matching-build public open-data export folder when available. Both label game-file facts `game_files_unconfirmed`.
3. The in-client explorer joins item IDs to vendor, drop, fishing-pool, trainer and recipe links, keeping unverified sources labelled. It shows copyable source URLs rather than trying to open a browser from WoW.
4. `.github/workflows/everloot-refresh.yml` fetches and opens a review PR with source changes after integration to main. It is not an automatic release.
5. `FishingAtlas/DATA-LICENSES.txt` and the in-game Source link popup carry attribution.

**Remaining content gate:** the branch now ships 60,550 source observation events normalized into indexed fishing/vendor/recipe/NPC relationships. The relevant build-matched client-file pack is populated (136 recipe definitions, 1,854 categories, 3,356 selected relationships), 0 eligible school-object positions are present in the observed snapshot, and client UI compatibility remains untested. Review future snapshots for availability, lineage, licensing and performance. A game-file item category is not proof of server availability.

## Acceptance gate
- Stable snapshot pagination and/or bulk checksum checks.
- Numeric ID cross-linking and client/build compatibility checks.
- No source promotion from classic/reference to Forever-verified without independent evidence.
- In-app links back to upstream item/vendor/zone pages where available and visible credit for included data.
- User testing for maps, TomTom calls, and tooltip API behavior on interface 16001.
- Regression test on a representative set of fish, recipes, schools, vendors and zones.

The full public observation snapshot is now bundled and documented in docs/DATABASE-COVERAGE.md. Relevant build-matched client-file metadata is bundled as a separate, unconfirmed layer. The full upstream 31,981-item catalog is not copied wholesale, and missing names/icons/availability cannot be inferred from game-file records.
