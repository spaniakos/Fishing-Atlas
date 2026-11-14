-- SPDX-License-Identifier: GPL-3.0-or-later
-- Regression: public Azeroth observations must not flood a fishing-specific atlas.
local ns = {
  data = {
    referenceZoneFish = {[1413] = {{id = 6522}}},
    referenceVendors = {
      {id = 10, name = "Fishing supplier", items = {6256}, title = "Trade goods"},
      {id = 12, name = "Random merchant", items = {9999}, title = "Trade goods"}
    },
    everloot = {
      fishing = {[6522] = {{mapID = 1413, installs = 3}}},
      poolItems = {},
      vendorItems = {
        [6256] = {{npcId = 11, installs = 3}},
        [9999] = {{npcId = 13, installs = 4}},
        [8959] = {{npcId = 99, installs = 2}}
      },
      itemNames = {[9999] = {name = "Random sword"}},
      npcs = {[11] = {name = "Fishing store"}, [13] = {name = "Weapon shop"}}
    }
  },
  storage = {db = {vendorObservations = {}}},
  catalog = {
    itemList = function()
      return {
        {id = 6256, category = "fishing_pole"},
        {id = 6522, category = "fish"},
        {id = 9999, category = "weapon"}
      }
    end,
    recipeList = function()
      return {{spellId = 1, outputItemId = 9000,
        ingredients = {{itemId = 6522}, {itemId = 2678}}},
        {spellId = 2, outputItemId = 9001,
        ingredients = {{itemId = 9999}}},
        {spellId = 3, outputItemId = 8957,
        ingredients = {{itemId = 8959}}}}
    end,
    recipe = function() return nil end,
    entity = function(_, id)
      if id == 6256 then return {category = "fishing_pole"} end
      return nil
    end,
    name = function(_, id) return "Item " .. id end,
    icon = function() return "icon" end
  }
}
assert(loadfile("FishingAtlas/Data/FishingScope.lua"))("FishingAtlas", ns)
local S = ns.fishingScope
assert(S.item(6256) and S.item(6522), "Fishing roots absent")
assert(S.item(9000) and S.item(2678), "Fish recipe graph not expanded")
assert(not S.item(9999) and not S.item(9001), "Unrelated items included")
assert(S.item(8959) and S.item(8957),
  "Raw Spinefin Halibut and its cooked recipe must be in fishing-related Items")
assert(not S.isFishingRoot(8959),
  "Vendor/cooking relevance must never claim a fish was caught by fishing")
assert(S.vendor(99), "A vendor selling a fishing-related Cooking reagent is relevant")
assert(S.vendor(10) and S.vendor(11), "Fishing merchants missing")
assert(not S.vendor(12) and not S.vendor(13), "Unrelated merchants included")
print("fishing-only catalog scope tests passed")
