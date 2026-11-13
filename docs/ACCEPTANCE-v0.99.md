# Fishing Atlas v0.99: WoW Forever in-game acceptance

**Database baseline:** client build 70888, interface 16001. **Current observed client:** 1.60.1 build 70938 on November 13, 2026. The build can advance without changing interface 16001.
**Tester:** player running the actual Forever client.
**Status:** All cases **NOT TESTED** until explicitly reported by the tester.
**Procedure:** Run one case at a time, return PASS or FAIL with notes and complete
Lua error if any. Developers fix, run CI, and request a single retest before advancing.
Back up `WTF/Account/.../SavedVariables/FishingAtlas.lua` before migration checks.

## T01 — Clean install and boot
1. Remove any *older Fishing Atlas addon folder*, preserving SavedVariables separately.
2. Install the build ZIP so `FishingAtlas/FishingAtlas.toc` is directly below AddOns.
3. Enable the addon and log in; then type `/fa diagnose`.
**Expected:** No Lua errors; version 1.60.1/build 70938/interface 16001 reported (or a newer compatible build);
addon loads without disabling another addon; diagnostics reflect actual API availability.

## T02 — Manual Fishing Space binding
1. Out of combat, run `/fa fishing on` and press Space once by water with a pole equipped.
2. Check whether Fishing cast begins, then interact with the bobber **manually**.
3. Run `/fa fishing off`; verify Space returns to the previous client binding.
4. In combat, try `/fa fishing on` and report the restriction/error.
**Expected:** No unattended hook/loot. Secure casting works only if the client permits;
binding restores when disabled. Note **any** protected-action errors.

## T03 — Fishing gear preferences
1. Run `/fa gear`; choose a known pole and lure ID.
2. Run `/fa pole 6256` and `/fa lure 6529`; then `/fa profile`.
3. Check equipped weapon and lure state; `/reload`; run `/fa profile` again.
**Expected:** Preferences persist without automatically equipping or replacing weapons.

## T04 — School-candidate journal
1. Stand near a visually identifiable school; `/fa school Visible School Name`.
2. Repeat the command nearby and run `/fa schools` and `/fa stats`.
3. Move zone; run `/fa schools`, then return and `/reload`.
**Expected:** Same-zone nearby entries deduplicate, persist through reload, and
display as **player positions near schools**, not exact school-spawn coordinates.

## T05 — World map and proximity alerts
1. `/fa add TestRiver` at a known spot; open and close world map.
2. Inspect whether a historical pin appears in the right zone.
3. Run `/fa radius 1` and `/fa notify on`; move away and return.
**Expected:** Marker placement aligns with saved *player* position, no phantom
pins in other maps, alert cooldown prevents repeated spam. Report zoom or UI conflicts.

## T06 — TomTom integration
1. With TomTom enabled, run `/fa waypoint`.
2. Save a school candidate; run `/fa waypointschool`.
3. Disable TomTom and repeat commands.
**Expected:** Waypoints for saved player positions when available; clean fallback
when TomTom is absent. Neither waypoint asserts a currently active school.

## T07 — Fish encyclopedia and search
1. Run `/fa fish`, `/fa find nightfin`, `/fa catalog`.
2. Open `/fa`; select Fish, Gear, and Zones and enter a search query.
3. Search by a known item ID and by a nonexistent name.
**Expected:** Indexed records and source-confidence labels appear; unknown
IDs don't crash; client-derived spell/item names resolve where available.

## T08 — Cooking and Fish-to-Table
1. Run `/fa recipeid 18243`, then `/fa plan 18243 2`.
2. Compare missing ingredients with actual bag/bank counts, noting container behavior.
3. Open the Recipes UI tab and inspect a recipe and its ingredient list.
**Expected:** Nightfin Soup recipe references 13759, 159 and result item 13931;
counts scale by crafts; no invented recipe vendor or server-availability claims.

## T09 — Catch journal and statistics
1. Catch a real fish and record `/fa caught 2 Raw Nightfin Snapper`.
2. Run `/fa collection` and open the Journal tab.
3. Reload, repeat and compare totals.
**Expected:** Recorded entries persist and totals accumulate correctly;
automatic loot correlation must be separately assessed and reported.

## T10 — SavedVariables upgrades
1. Back up existing `FishingAtlasDB`; install v0.99 over v0.6 or later SavedVariables.
2. Enter game and check `/fa stats`, `/fa school`, `/fa profile`.
3. Reload and, if possible, log in to a second character on the same account.
**Expected:** No destructive migration, retained historical observations,
schema version 3, account-wide persistence.

## T11 — Performance and addon coexistence
1. Leave world map and Fishing Atlas UI open for several minutes.
2. Test with TomTom and your other fishing/map addons enabled.
3. Fish, switch zones, open merchant, reload and repeat.
**Expected:** No unbounded Lua errors, repeating alerts, UI input capture,
noticeable excessive frame stutter or protected-action conflicts.
**Record:** Full addon list, any error text, and reproduction sequence.

## T12 — Release packaging and final regression
1. Verify extracted `FishingAtlas/FishingAtlas.toc`, `FishingAtlas/LICENSE`,
   matching v0.99.0 version and checksum.
2. Run T01 smoke again; toggle Fishing Space on/off and reload.
3. Verify all 12 case results and outstanding issues are recorded.
**Expected:** Valid install package, version-consistent files, reproducible ZIP,
tests passing and unresolved client failures explicitly tracked.

## Reporting format

```text
Case: T01
Result: PASS / FAIL
Client: 1.60.1.70888 / 16001
Other addons enabled:
Steps performed:
Actual result:
Lua error (if any):
Screenshot (if useful):
```

**Release condition:** `v0.99.0` is an **acceptance candidate**, not a
fully client-verified v1.0. The 12 tests remain NOT TESTED until player execution.
