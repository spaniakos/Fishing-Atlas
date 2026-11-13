-- SPDX-License-Identifier: GPL-3.0-or-later
-- Source graph checks: three installs, exact object coords and navigation.
local ns = {
  data = {everloot = {
    meta = {credit = "Data from Everloot (https://everloot.app), CC BY-SA 4.0.",
      dataAsOf = "2026-11-12"},
    itemNames = {[6303] = {name = "Raw Mackerel"}},
    npcs = {[1] = {name = "Fishing Merchant",
      spots = {{mapID = 1411, x = 0.5, y = 0.3, installs = 3, near = true}}}},
    vendorItems = {[6256] = {{npcId = 1, installs = 3, reports = 7}}},
    drops = {[6303] = {{npcId = 1, installs = 1, windows = 1}}},
    fishing = {[6303] = {{mapID = 1411, installs = 3, windows = 5}}},
    poolItems = {[6303] = {{objectId = 77, name = "Pool", installs = 3,
      windows = 4, mapID = 1411, x = 0.6, y = 0.4}}},
    schools = {{name = "Pool", objectId = 77,
      spots = {{mapID = 1411, x = 0.6, y = 0.4, installs = 3}}}},
    recipes = {[3371] = {productItemId = 6303, installs = 3, name = "Cooked Fish"}},
    trainers = {[3371] = {{npcId = 1, installs = 3}}},
  }, catalog = {meta = {}}},
  catalog = {entity = function() return nil end},
  util = {validCoordinate = function(v) return type(v) == "number" and v >= 0 and v <= 1 end},
}
assert(loadfile("FishingAtlas/Data/ObservedRuntime.lua"))("FishingAtlas", ns)
local S = ns.sources
assert(S.itemName(6303) == "Raw Mackerel")
assert(S.vendorsForItem(6256)[1].confidence == "observed_confirmed")
assert(S.dropsForItem(6303)[1].confidence == "observed_provisional")
assert(S.dropsForItem(6303)[2].kind == "pool")
assert(S.fishingForItem(6303)[1].mapID == 1411)
assert(S.craftedItem(6303)[1].spellId == 3371)
assert(S.trainersForRecipe(3371)[1].title == "Fishing Merchant")
assert(S.schoolLocations("Pool")[1].exact)
assert(S.schoolLocations("Pool")[1].x == 0.6)
assert(#S.schoolLocations("None") == 0)
assert(#S.vendorLocations(101010) == 0)
assert(S.linkFor({kind = "item", id = 6303}) ==
  "https://everloot.app/database/items/6303")
assert(S.linkFor({kind = "vendor_reference", id = 1}) ==
  "https://everloot.app/database/npcs/1")
assert(S.creditFor({kind = "observed_npc", id = 1}):find("Everloot"))
assert(S.creditFor({kind = "vendor_reference", id = 44}):find("Finddon"))
assert(S.creditFor({kind = "gamefile_recipe", id = 3371}):find("Blizzard"))
print("Everloot observed source graph tests passed")
