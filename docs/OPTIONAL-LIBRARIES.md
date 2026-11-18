# Optional Forever-aware library providers (v1 beta integration candidate)

## Policy
Fishing Atlas remains an offline, standalone addon. Optional standalone LibItemDB
and LibProfessionDB are **not bundled**, automatically downloaded, or required
for install. The TOC lists them in OptionalDeps so WoW loads them first when
installed. A known Vanilla/Era ID is not proof of Forever availability.

## Verified API surface
- LibItemDB-1.0: `LibStub(name, true)`, `IsReady`, `GetName(itemID)`,
  `GetLink(itemID)`. See https://www.curseforge.com/wow/addons/libitemdb .
- LibProfessionDB-1.0: `IsReady`, `GetGameVersion`,
  `GetRequiredSkill(spellID)`, `GetRecipeItem(spellID)`,
  `GetReagents(spellID)`, optional `IsBorrowed`.
  See https://www.curseforge.com/wow/addons/libprofessiondb .
- LibItemDB documentation does **not** guarantee a GetGameVersion method.
  Our first pass intentionally refuses to trust it as a Forever item provider
  unless a running version exposes that explicit method; `/fa diagnose`
  reports `version_unknown`. This is a compatibility gap to resolve from
  the actual installed Forever library API, **not** a reason to pretend its
  Vanilla records are Forever-verified.

## Runtime resolution and fallback
- Item name: C_Item.GetItemInfo -> explicitly Forever-gated LibItemDB
  -> Forever observed names -> bundled catalog/reference -> unresolved ID.
- Recipe skill and scroll: existing verified recipe/client/observation
  precedence -> LibProfessionDB Forever query -> unknown. Library-supplied
  borrowed Classic ranks are labeled `borrowed_classic_reference`.
- Learned recipes remain client/character-specific; presence in the recipe
  library never means the player knows the recipe.
- Vendor stock, pool spawns, quest reward availability, and acquisition
  coordinates do not silently inherit library claims; preserve source/built
  time and observation evidence before accepting them into the map.

## In-client acceptance
1. Run `/fa diagnose` without either library. Both should report missing.
   Verify the existing 136-recipe baseline remains available.
2. Install a Forever-compatible LibProfessionDB; repeat. It must report ready.
   Compare Nightfin Soup (18243), Crispy Bat Wing (15935), teaching scrolls,
   reagents and learned status against our existing verified references.
3. Install LibItemDB. Check `/fa diagnose` and record the actual API game-version
   metadata. If `version_unknown` appears, provide the library version/API
   output before enabling data; fallback must remain intact.
4. Install an incompatible/wrong-game version, then disable one library. No
   nil errors, false vendor/pool pins, changed item IDs, or character-known
   recipes are permitted.
5. Check Cooking scanner, manual additions, loaded/unloaded item cache,
   language fallback, saved preferences, and reload. Finally test performance.

## Coverage audit still outstanding
The libraries have broader offline datasets, but their exact Forever build,
record completeness and source claims have not yet been exhaustively compared
with our build-70888 catalog, the 60,550-observation Everloot snapshot or
the more recent EG observed Cooking source. No bundled records have been
deleted. Do not merge this feature until in-client comparison demonstrates
that the external library genuinely improves coverage without regressing
accuracy.
