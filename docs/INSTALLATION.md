# Fishing Atlas installation and troubleshooting

Target: **WoW Forever 1.60.1.70888** (interface 16001).

1. Download the `fishing-atlas-ci-zip` artifact from a successful `main` CI run, or the tagged release archive once published.
2. Unzip it under your World of Warcraft Forever `Interface/AddOns` directory so the manifest is at `Interface/AddOns/FishingAtlas/FishingAtlas.toc`. The game folder name varies by installation.
3. Enable Fishing Atlas on the character-selection AddOns screen.
4. Enter `/fa diagnose`; report the client version and API flags if a required feature is unavailable.
5. Enter `/fa` to open the explorer. The map overlay draws **your saved positions**, not guaranteed active fishing pools.
6. `/fa fishing on` attempts to bind Space to a secure manual Fishing spell button. `/fa fishing off` restores the normal binding. Never test protected bindings in combat.

**Testing caution:** This is a pre-release candidate, not validated against the live WoW Forever FrameXML runtime. If the addon triggers Lua errors, disable it and report the complete error, build and conflicting addons. Do not delete `FishingAtlasDB` without taking a copy.

### Data
- Client file recipes: may exist in the client without being obtainable on the server.
- Fishing school sightings: saved **player positions near a seen school**. Not verified game object coordinates.
- Equipment choices are stored preferences, not automatic equip operations.
- Vendor observations are time-stamped sightings, not guaranteed stock.
