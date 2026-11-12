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
