# v0.99.6 | Verified WoW Forever data policy and ingestion

The user requires **Forever data only**, not Vanilla/Classic borrowing.

## What established addons actually do

| Producer | Method | Why it is not equivalent to live verification |
|---|---|---|
| ATT v5.4.11 | Parses authored source under `.contrib/.db/forever` with a C#/Lua Parser; generates `db/Camelot/Categories/*.lua` for the 16001 client, including source-tree relationships (NPC -> vendor/recipe/zone). | Camelot generation and `awp=16001` constrain applicability; they do not demonstrate that an NPC sold the item on build 70938. The installed ZIP also has conflicting `LICENSE` (MIT) and `LICENSE.txt` (all rights reserved): do not bulk redistribute database rows. |
| QuestieDB 1.1.0 | Has `data/Forever`, static corrections, generator, source/baked equivalence/roundtrip checks, CBOR compressed TOC metadata and a versioned public `LibQuestieDB` API. | Its independent Forever flavor was initially converted from older Era data. Generator correctness is not live spawn verification. License and inherited contributions need review. |
| LibItemDB | Runs a Forever client item walk and builds a separate Forever offline table; resolves names/IDs independent of cache. | Client item existence does not prove where it drops or which vendor sells it. |
| LibProfessionDB | Builds Forever profession/recipe definitions from client files and exposes `IsBorrowed(spellID, field)`. | Some sources/hidden flags/skill requirements are explicitly borrowed from Vanilla. **Never ingest or display those borrowed fields**. |
| ForeverBeacon / ForeverDB / Everloot | Observe loot, merchant windows, items, NPCs and/or map/player positions; retain build/time and source provenance. | Actual observation is stronger, but coordinates may be the player's position and may become stale. |
| ForeverFishing v0.9.99 | Separate Forever fish guide, journal and reference data; user-supplied ZIP contains its `COPYRIGHT.txt`. | Original content and art are all-rights-reserved; inspect for compatibility ideas, do not copy into Fishing Atlas. |

## Data model

Persist each **relationship**, not just each entity. Example:

```json
{
  "subject": {"type": "item", "id": 6256},
  "predicate": "sold_by",
  "object": {"type": "npc", "id": 42},
  "evidence": {
    "flavor": "Forever",
    "build": "70938",
    "kind": "merchant_window_observation",
    "observed_at": "2026-11-13T12:00:00Z",
    "source": "player_capture",
    "location_precision": "player_position_near_npc"
  }
}
```

This is an **example schema with illustrative IDs** and is not real observed stock. Use the same shape for `found_in_zone`, `school_contains_fish`, `created_by`, `reagent_for`, `learned_from_trainer`, `dropped_by` and `quest_reward`. Separate item/spell identity from acquisition claims.

## Strict acceptance rules

1. Flavor must be **Forever**. Never fallback to a different flavor for missing records, including when it shares an item ID.
2. Item name/icon, spell name, recipe output/reagents and zone map art may be *client-confirmed* with a pinned Forever build. They are not live-server acquisition data.
3. Sold by, dropped by, learned from trainer, school spawn, fishing yields and exact NPC coordinates require matching **live Forever observations** (or Blizzard explicitly published server facts). A third-party screenshot/guide alone is not a sufficient machine-readable observation record unless reviewed and documented.
4. When two captures disagree, retain both and show conflict or recency. An old observation is not a universal guarantee.
5. Record per-edge `source`, `build`, `observed_at` and `kind`; distinguish player-near location from exact spawn.
6. A compiled Forever/Camelot addon database is a **candidate index**, not proof. Do not bulk import it into the verified set without supporting evidence or permission.
7. On missing evidence the UI must say **No verified source recorded**. It must never fabricate a drop, vendor, trainer, fishing school or TomTom pin.
8. All third-party code/data imports require license and redistribution approval. Use documented APIs when possible; never copy original ForeverFishing artwork.

## Implementation architecture

```text
Forever client DB2/hotfix/TOC extraction (item and recipe identities)
            + in-game SavedVariables captures (vendor, pool, drops, skill)
            + licensed source-specific adapters (ATT/QuestieDB/library references)
                                 |
                       Staging evidence ledger
                       (source, build, license)
                                 |
                    Validators and conflict review
                  /                         \
      approved client identities     approved live edges
                  \                         /
                  Indexed JSON + generated Lua 5.1
                        (both directions)
                                 |
                       Fishing Atlas runtime
                 /          |             \
          Fish/Recipes   Vendors/Schools    Map/TomTom
```

The `approved` set has **zero live-verified catalog entities as of v0.99.5**; its `database/catalog.json` currently has 449 entities (434 client-extracted and 15 historical references) and 136 client recipes from build 70888. Existing Finddon/Luredon references shown elsewhere in the addon must be quarantined from a strict verification-only production view until independently checked.

Use Python/Lua adapters in CI for imports, with deterministic Lua output, checksums, source manifests, negative fixtures (e.g. Vanilla flavor, no build, borrowed source, stale source, wrong NPC ID) and build diff reports. A release cannot claim new verified relationships without passing these gates.

## Updating independently

Keep `LibItemDB`, `LibProfessionDB` and (when its API is safe) `LibQuestieDB` as optional **installed, updateable** libraries. These provide lookup data at runtime without redistributing their source tables. The addon can use new installed-library versions without a Fishing Atlas rebuild.

Separately, update our **reviewed, version-pinned** snapshot via scheduled or manually triggered CI: scan upstream revisions, extract only Forever-native fields/observations, validate, generate a diff, and require review before publishing. WoW Lua cannot download the latest DB on its own. Update via normal addon manager/GitHub release.

## Source and rights references

- ATT: https://github.com/ATTWoWAddon/AllTheThings ; local installed version v5.4.11
- QuestieDB Forever: https://github.com/Questie/QuestieDB/blob/master/docs/forever.md
- QuestieDB API: https://github.com/Questie/QuestieDB/blob/master/docs/api.md
- LibItemDB: https://www.curseforge.com/wow/addons/libitemdb
- LibProfessionDB: https://www.curseforge.com/wow/addons/libprofessiondb
- ForeverBeacon: https://github.com/Thunderz96/forever-addon-kit/tree/main/addons/ForeverBeacon
- ForeverDB verification: https://foreverdb.net/verify
- Everloot: https://github.com/Everloot/everloot

Reviewed against the user-supplied ZIP 2026-11-13 and current source documentation. No third-party database was copied into this document or addon.
