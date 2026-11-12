# Fishing Atlas: v0.7 to v0.99 release train

Target: **WoW Forever 1.60.1.70888**, Interface **16001**, Lua **5.1**.
Each milestone is developed on its own `feat/vX.Y-...` branch, validated in CI, reviewed as a PR, and merged to `main` before beginning the next milestone. No tags until the associated release is actually packaged and verified.

## v0.7.0: Database foundation (blocking)
- [x] Record exact Forever client build and provenance policy.
- [x] Define canonical ID-based entities and relationship types.
- [x] Implement deterministic JSON -> Lua generator with schema and integrity validation.
- [x] Wire generator freshness check into CI and release packaging.
- [ ] Import a broad licensed source of build-matched client records (not placeholders).
- [ ] Produce coverage and discrepancy reports per entity type and validation status.
- [ ] Validate source licensing before bulk redistributing extracted datasets.

**Gate:** No orphaned foreign keys, no duplicate typed IDs, every nontrivial assertion has a source and build. Unknowns remain unknown. Tests prove reproducible outputs.

## v0.8.0: Encyclopedia population (blocking)
- [ ] Fish, catchable objects, schools, zones, skill requirements, gear, lures, quests, trainers and vendors.
- [ ] Cooking spells, recipe items, cooked outputs, ingredients and acquisition paths, connected by numeric IDs.
- [ ] Search and navigation in-game for every supported content category.
- [ ] Distinguish client-defined facts from server observations; source attribution and coverage numbers.
- [ ] Cross-check disagreements between at least two credible sources.
- [ ] Do not invent pool coordinates, catch probabilities or vendor stock.

**Gate:** Published coverage report and no unverified data shown as confirmed Forever facts.

## v0.9.0: Fishing interaction and discoveries
- [ ] Verify secure one-key casting and manual bobber interaction against build 70888.
- [ ] Optional lure and equipment profiles with safe restore/combat restrictions.
- [ ] World map/minimap markers, confirmed observations, deduplication, alert cooldowns, optional TomTom.
- [ ] Persist player positions separately from actual pool-coordinate observations.

**Gate:** mocked API tests plus explicit manual client tests; no unattended botting.

## v0.95.0: User experience
- [ ] Searchable compact in-game GUI, category filters and navigation.
- [ ] Fish-to-Table planner with recipes, vendors, missing ingredients and fishing routes.
- [ ] Collection journal, statistics and accessible notification settings.
- [ ] Distinct offline database and account-wide observed data.

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
