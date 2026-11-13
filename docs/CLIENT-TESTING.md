# WoW Forever manual testing

This document describes checks we cannot execute in CI.

1. Log into Forever client with Fishing Atlas enabled. Verify no Lua errors on startup or reload.
2. Check `/fa`, `/fa add Test`, `/fa nearby`, `/fa stats` and relog. Observations should persist.
3. Out of combat, use `/fa fishing on`: Space should cast Fishing only while mode is enabled.
4. A bobber must be interacted with manually using the game-supported binding; **no automated hooking** is implemented.
5. Use `/fa fishing off`: original Space binding must work again.
6. Check cast mode while in combat: no secure-action errors or rebindings.
7. Reload while mode enabled, confirm no stale override bindings remain.
8. Check TomTom optional integration with `/fa waypoint`.
9. Check localized clients: the spell name `Fishing` must resolve; this is an outstanding compatibility issue.

Record client build, locale, steps and screenshots when any check fails. Do not claim in-game compatibility from Lua unit tests.


## v0.99.6 in-client acceptance: record results for every step

These checks require the actual **WoW Forever 1.60.1.70888** UI and cannot be inferred from mock CI. Record `PASS/FAIL`, screenshot, Lua error, locale, resolution, mapId and whether TomTom is installed.

1. Hover a recipe's **Cooking skill**, **Produces** and each ingredient. Expect readable label; produces and ingredients should show native item tooltips when the client resolves their IDs.
2. Click an ingredient or product. Expect the **item** explorer to show its Vendor, Drops, Crafted and Map sections. A missing source must say unknown, not invented.
3. Click a vendor from the item inspector. Expect a vendor detail view, native goods item tooltips, selectable goods and source/copyable URL.
4. Open a recipe Sources tab. Check observed trainers, recipe-scroll vendors and drops if imported; without imported data see **Acquisition unknown**.
5. Enter a known zone with mapped vendor reference. Click the vendor in the right third panel; hover shows tooltip; click opens matching NPC. Check left/right click source evidence.
6. Select a zone with known native map art. The thumbnail should preserve correct aspect and pins should align with the source coordinates. Check maps with zero tiles and maps with >1 texture tile.
7. With TomTom installed, select a mapped vendor, click TomTom, check marker in expected zone and coordinates. Repeat **without** TomTom; expect nonfatal unavailable message.
8. Open World Map from a selected zone/vendor. Validate the real client API call, zoom and mapId; report any case where the popup does nothing.
9. Select Schools; observe named zones for **actual** recorded school objects vs personal historical `nearby` sightings. Confirm neither is called an exact active pool when only personal position is available.
10. Drag the minimap emblem around the rim, reload, and verify saved angle. Test small minimap, 4:3 viewport, ultrawide and UI scale.
11. Click **Source link** on a reference item, observed item and recipe. Confirm URL is selectable, provenance correctly credits authors, and unknown data isn't called confirmed.
12. Benchmark opening explorer, filtering a long vendor list, switching every tab and reloading. No Lua taint, nil callbacks, or crash.
13. Verify ZIP contains both add-on files and `FishingAtlas/DATA-LICENSES.txt`. Ensure observed corpus install identifiers are absent from the Lua file.

A successful automated build **does not** satisfy the above manual gate.
