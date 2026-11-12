# Fishing Atlas v0.99.0 candidate notes

**Candidate, not v1.0.** Built for WoW Forever client `1.60.1.70888` /
`16001`. Live in-game testing **has not yet been completed**.

## Install
Download the successful `main` GitHub Actions `fishing-atlas-ci-zip` artifact.
Extract `FishingAtlas-v0.99.0.zip` into the Forever `Interface/AddOns` folder.
Confirm `FishingAtlas/FishingAtlas.toc` is in the correct location.

## First commands
- `/fa diagnose`: show API/build compatibility
- `/fa`: open explorer
- `/fa catalog`, `/fa fish`, `/fa gear`, `/fa find nightfin`
- `/fa recipeid 18243`, `/fa plan 18243 2`
- `/fa add test`, `/fa school Floating Wreckage`
- `/fa fishing on` and `/fa fishing off`, **only outside combat**

## Known boundaries
- 23 named fish, 11 gear items, 46 maps and 136 recipes, NOT exhaustive.
- No verified active-school spawn map or reliable drop-rate predictions.
- Client-extracted presence never proves in-game availability.
- School observations are player positions, not exact school-object coordinates.
- Gear profiles do not auto-equip; Space binding and map overlay need live testing.
- No automatic hooking/looting.
- GPL-3.0-or-later code; upstream source attributions in database/docs.

## Acceptance plan
[12 test cases](ACCEPTANCE-v0.99.md), all initially **NOT TESTED**.
[Track results](TEST-RESULTS-v0.99.md). A verified v1.0 depends on actual
player reports, not passing unit tests alone.
