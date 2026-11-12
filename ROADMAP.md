# Fishing Atlas: v0.7 to v0.99 release train

Target: **WoW Forever 1.60.1.70888**, Interface **16001**, Lua **5.1**.
Each milestone is developed on its own `feat/vX.Y-...` branch, validated in CI, reviewed as a PR, and merged to `main` before beginning the next milestone. No tags until the associated release is actually packaged and verified.

## v0.7.0: Database foundation (blocking)
- [x] Record exact Forever client build and provenance policy.
- [x] Define canonical ID-based entities and relationship types.
- [x] Implement deterministic JSON -> Lua generator with schema and integrity validation.
- [x] Wire generator freshness check into CI and release packaging.
- [x] Import a build-matched Cooking/Fishing client recipe extract (133 + 3 records); broader game records remain outstanding.
- [x] Produce baseline coverage reports; independent discrepancy and completeness review remains outstanding.
- [x] Document upstream client-extract provenance and source credits; review any future player-observation datasets separately.

**Gate:** No orphaned foreign keys, no duplicate typed IDs, every nontrivial assertion has a source and build. Unknowns remain unknown. Tests prove reproducible outputs.

## v0.8.0: Initial encyclopedia snapshot (documented partial coverage)
- [x] Curate 23 reference fish and 11 fishing equipment IDs; 46 build-matched zone maps. Schools, live skill requirements, quests, trainers and vendor locations are still incomplete.
- [x] Import 136 Cooking/Fishing spell-output-reagent relationships; recipe scroll IDs and acquisition paths remain incomplete.
- [x] Runtime ID/name lookup, category browsing and /fa find; full graphical navigation remains for v0.95.
- [x] Separate client-extracted recipes from locally recorded merchant observations and historical references.
- [ ] Cross-check live acquisition and spawn data between two sources (pending observation exports).
- [x] Keep unknown pool coordinates, catch probabilities and vendor stock absent; document gaps.

**Gate:** Published initial coverage report with transparent missing categories and no unverified data shown as confirmed Forever facts. An exhaustive server-world database is NOT claimed.

## v0.9.0: Fishing interaction and discoveries
- [ ] Verify secure one-key casting and manual bobber interaction against build 70888.
- [x] Store optional fishing pole and lure preferences; deliberately no automatic gear swapping before client testing.
- [x] World map overlay for saved player positions, school-candidate records, deduplication, alert cooldowns and optional TomTom. Minimap integration and automatic school-object detection need in-client validation.
- [x] Persist generic player positions and manually noted school-proximity candidates separately; neither claims exact school-object coordinates.

**Gate:** mocked API tests plus explicit manual client tests; no unattended botting.

## v0.95.0: User experience
- [x] Add on-demand searchable in-game explorer with category tabs, pagination and details (client UI verification pending).
- [x] Build-70888 recipe ingredient planner and inventory deficits; vendor acquisition links remain unknown until verified.
- [x] Browser tabs for catch journal, school candidates and vendor observations; alert toggle and existing statistics.
- [x] Keep build-matched offline encyclopedia separate from SavedVariables observations.

**Gate:** No missing-link crashes, usable UI, documented user flows.

## v0.98.0: Hardening
- [ ] SavedVariables migrations, fuzz tests, data generator consistency and regression tests.
- [ ] Compatibility checks (TomTom, BagBrother, other fishing addons).
- [ ] Original icons/map pin art where necessary, localization support.
- [ ] GitHub Action ZIP, changelog, checksums and installation documentation.

**Gate:** CI green, package reproducible, no known release-blocking static defects.

## v0.99.0: Pre-v1 acceptance candidate
- [ ] Publish a tagged release with downloadable ZIP, matching TOC version and checksums.
- [ ] Complete T01-T12 scripted acceptance checklist with expected results.
- [ ] Mark in-game checks *pending player verification*, not falsely passed.
- [ ] Fix blockers through versioned patches, update change log and reissue candidate.

**Gate:** Candidate is ready for the player's step-by-step in-game testing. v1.0 requires the player's confirmed results.

## Licensing and database policy
- Addon source: GPL-3.0-or-later.
- External datasets are **not** automatically GPL compatible; maintain separate provenance and permissions.
- Wowhead and reference addons are comparison sources until redistribution rights are established.
- Never claim client data proves live vendor stock, active pool spawns or drop rates.
