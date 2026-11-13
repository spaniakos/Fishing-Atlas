# Fishing Atlas changelog

## v0.99.6 — Evidence-linked explorer, source pipelines (draft)
- Clickable/hoverable item, recipe, vendor and map relationships; explicit acquisition sections.
- Sourced observed fish, vendors, trainer recipes, drops and school-object sightings, without treating old Classic references as Forever-confirmed.
- Map preview aspect-ratio/pin alignment changes, optional TomTom path, and larger minimap button with contextual icons.
- Offline Everloot corpus and client-file export adapters, distinct CC BY-SA/Blizzard attribution, stable snapshot verification, source checksums and diff report.
- Daily/dispatch Everloot data-refresh PR workflow, and import unit fixtures for three independent installs, privacy, checksum and build gates.
- Imported the complete public Everloot observation corpus as a separately licensed offline Lua snapshot (2026-11-13T14:10:21.029Z).
- Added Items Explorer navigation for the offline observed item relationships.
- **Pending:** matching-build full game-file export, client verification and exhaustive coverage.



## v0.99.0 — Pre-v1 candidate (client acceptance pending)
- Complete CLI and on-demand searchable explorer window across seven categories.
- Offline catalog: 136 extracted Cooking/Fishing recipe relationships; 46 client maps;
  23 curated historical/reference fish; 11 equipment records.
- Catch journal, merchant inventory observations, school-proximity observations,
  TomTom support and experimental historical map pins.
- Secure manual Fishing Space binding where supported by the client.
- Bag-aware Fish-to-Table ingredient planner.
- Account-wide schema-v3 migrations, protected API diagnostics and regression tests.
- Deterministic installable ZIP packaging with license and SHA-256 checksums.
- T01–T12 player acceptance procedures.

**Known limitations:** In-game validation has not occurred; fishing-school spawn
coordinates and live vendor acquisition are not complete; Space binding and map
overlay compatibility must be verified in WoW Forever. No unattended bobber hooking
or looting; no automatic gear switching. Data remains incomplete rather than invented.

## v0.98.0 — Hardening
- ZIP builder, license, checksums, migrations, diagnostics and CI artifacts.

## v0.95.0 — Explorer
- Searchable UI, tabs, journal, recipes and ingredient deficit planner.

## v0.9.0 — Discovery
- Separate manual school-candidate observations, map pins, gear profiles.

## v0.8.0 — Initial catalog
- Imported client recipe/map references and curated fish/gear IDs.

## v0.7.0 — Canonical database
- Versioned JSON source, deterministic Lua generator, integrity tests.

## v0.1.0–v0.6.0 — Initial foundation
- Addon skeleton, controls, observation storage, catch journal, cooking guide prototypes.
