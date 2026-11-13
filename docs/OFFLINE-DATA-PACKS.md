# Bundled offline data: installation, bootstrap and refresh

## Does the player need Everloot?
**No.** Fishing Atlas never reads Everloot SavedVariables, needs no Everloot addon,
does not use an Everloot API key, and never makes HTTP calls inside WoW.
The installable FishingAtlas folder includes every Lua data pack listed by
`FishingAtlas.toc`. The current baseline works even without Internet access.

## Bundled layers
| File | Licensing/provenance | Meaning |
| --- | --- | --- |
| `Data/Catalog.lua` | FishingAtlas catalog, per-record origin | Client-extracted recipes/maps and selected references |
| `Data/ReferenceVendors.lua` | Finddon/ForeverDB/CMaNGOS attribution in file | Historical vendor candidates, **not guaranteed current stock** |
| `Data/ReferenceSchools.lua` | Classic references | Names only, not confirmed Forever spawns |
| `Data/EverlootObserved.lua` | **CC BY-SA 4.0** Everloot contributors | Verified independent player evidence, **only after import** |
| `Data/EverlootGameFiles.lua` | Blizzard game files, not CC BY-SA observed data | Build-specific **unconfirmed** client metadata |
| `DATA-LICENSES.txt` | Complete shipped credits | Read this when redistributing or modifying the data |

The initial observed pack is now populated from the complete public corpus (snapshot 2026-11-13T14:10:21.029Z). Raw SHA-256: b70c4a280ba90e74eec66e3bbd4958aa1a4c1f7f0c9ce9fa96b0ae4897915ecd. The separate full game-file pack is still empty, and a missing school-object observation is unknown rather than evidence that none exist. Never edit generated Lua by hand.

## Bootstrap once and refresh repeatedly
A release builder (not the user) runs:
```sh
python3 scripts/seed_offline.py
python3 scripts/build_catalog.py --check
python3 -m unittest discover -s tests -p 'test_*.py'
```

The seed tool first reads Everloot's `https://data.everloot.app/latest.json`,
locates its immutable `<stamp>/index.json`, verifies the separately licensed
observed `corpus.ndjson` row count, byte size and SHA-256, then uses the
documented offline import generator. It preserves the upstream snapshot
date, source URL and raw corpus checksum inside the output.

If the bulk export is **unpublished or valid-but-empty**, the builder falls
back to the paginated public observation API. It checks that every page
has the same `dataAsOf` and restarts if the snapshot changes.
Large corpus harvests may need a **free Everloot API key**, set only as
`EVERLOOT_API_KEY` on the build runner/GitHub Actions secret. **Never ship it.**

If both sources fail, the build fails and preserves the previous
already-bundled data. A timeout, rate limit or empty response is not
an excuse to publish an empty snapshot as complete.

Outputs:
- `database/observed/everloot-normalized.json`
- `database/observed/last-diff.json`
- `FishingAtlas/Data/EverlootObserved.lua`

All output rows contain aggregated evidence, **not install IDs**.
Three independent installs are required for confirmed evidence.
Less support is explicitly provisional, and a player standing near
a fishing pool is not an exact pool location.

### Release flow
1. Fetch a complete source snapshot on the builder (bulk export preferred).
2. Validate licenses, checksums, build compatibility, records and attribution.
3. Generate offline Lua; compare the deterministic normalized snapshot and last diff.
4. Review new/disputed evidence, client-version changes, and UI cross-links.
5. Run CI and in-client acceptance for map/tooltip/TomTom behavior.
6. Merge reviewed data and package the addon. Git commit/tag preserves the snapshot checksum and provenance of each version.
7. For later Everloot updates, the scheduled `everloot-refresh.yml` opens a data PR. It never silently rewrites a released addon.
8. Users update **FishingAtlas** itself to receive new data, regardless of whether they have Everloot.

A new client build requires revalidating the separate game-file pack;
do not promote an observation from one game build into a newer build without
applicable evidence. Client metadata is not proof of live vendor stock,
recipe availability, school spawns or drop rates.

## Data sources
- Corpus docs: https://everloot.app/docs/api/corpus-public
- Bulk docs: https://everloot.app/docs/api/data-files
- Open exports: https://everloot.app/database/download
- License: https://everloot.app/docs/licence
- Everloot open-source policy: https://github.com/Everloot/everloot/blob/main/docs/OPEN_DATA.md

Credit for Everloot observed data:
> Data from Everloot (https://everloot.app), CC BY-SA 4.0.
