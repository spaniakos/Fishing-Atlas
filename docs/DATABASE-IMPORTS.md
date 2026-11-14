# Database imports and evidence gates

Target client: WoW Forever **1.60.1.70888** (interface 16001).

## Source categories
- **Client extracts**: item, spell and recipe IDs; client presence does not prove server availability.
- **In-game observations**: merchant inventory snapshots, fish catches and player positions.
- **Historic references**: Classic guides and public sites; never marked Forever-confirmed without corroboration.
- **External datasets**: imported only with provenance, build and redistribution rights.

## Curated import workflow

1. Obtain a legally reusable export from its publisher.
2. Review records and adapt them to the normalized `database/source-pack.example.json` format. Preserve provenance **per entity and recipe**.
3. Record the source version, license, URL, original checksum and access date in the associated pull request.
4. Validate locally: `python3 scripts/import_curated.py source-pack.json --check`.
5. Merge accepted records: `python3 scripts/import_curated.py source-pack.json --write`.
6. Run `python3 scripts/build_catalog.py` and all tests. Review coverage differences.
7. External datasets with CC BY-SA obligations require visible attribution and license separation, not a silent change to GPL.

**Important:** the `reviewed` flag is a human approval gate, not an assertion that every record is live verified.

## In-game vendor observations
A merchant scan records an NPC ID, the item IDs visible, timestamp and current build in
`FishingAtlasDB.vendorObservations`. Unknown NPC IDs are skipped. Merchant inventory is
observed, not guaranteed permanent; it does not provide drop rates or fishing school locations.

## External license examples
Everloot's player observations are CC BY-SA 4.0, with its own mandatory credit notice.
Its game-file layer is labeled as Blizzard game data and unconfirmed.
AHledger restricts API retention and large-scale archival. Do not bulk copy its API data.

## Coverage gate for v0.8
v0.8 is **incomplete** until fish, equipment, recipes, schools and acquisition data have useful
coverage and public-source conflicts are resolved. Do not use passable unit tests as a substitute
for populated content.


## v0.99.6 automated Everloot offline adapters

`scripts/import_everloot.py --input corpus.ndjson --write` loads licensed observed records (or `--fetch` pages the read-only public corpus). It checks `dataAsOf` across pages, deduplicates reported events, counts distinct installs and strips install pseudonyms. Generated artifacts: `FishingAtlas/Data/EverlootObserved.lua`, `database/observed/everloot-normalized.json`, `database/observed/last-diff.json`. One install remains provisional; three agreeing installations qualify for an `observed_confirmed` *relationship*, not proof of permanent spawn.

`scripts/import_everloot_gamefiles.py --export <export-folder> --write` reads the **separately licensed**, game-file subset of a matching Everloot open data export and verifies manifest checksums. Generated artifacts: `FishingAtlas/Data/EverlootGameFiles.lua` and `database/game-files/everloot-gamefiles.json`. A mismatch with build `1.60.1.70888` is rejected. The client-game-file data is © Blizzard Entertainment, Inc., not CC BY-SA player observations.

The `.github/workflows/everloot-refresh.yml` workflow requests a review PR for source updates. No API key is required by players. A missing, incomplete, throttled, inaccessible or unstable upstream response is a failed import, **not** evidence of a zero-size database.
