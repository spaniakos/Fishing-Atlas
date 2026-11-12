-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {catalog = {
  entities = {{type = "item", id = 13759, name = "Item #13759"},
              {type = "spell", id = 18243, name = "Spell #18243"}},
  recipes = {{spellId = 18243, profession = "Cooking", outputItemId = 13931,
              ingredients = {{itemId = 13759, amount = 1}}}}
}}}
assert(loadfile("FishingAtlas/Data/CatalogRuntime.lua"))("FishingAtlas", ns)
assert(ns.catalog.recipe(18243).profession == "Cooking")
assert(ns.catalog.entity("item", 13759).id == 13759)
assert(not ns.catalog.entity("item", 999999))
assert(ns.catalog.name("item", 13759) == "Unresolved item #13759")
GetItemInfo = function(id) if id == 13759 then return "Raw Nightfin Snapper" end end
GetSpellInfo = function(id) if id == 18243 then return "Nightfin Soup" end end
assert(ns.catalog.name("item", 13759) == "Raw Nightfin Snapper")
assert(ns.catalog.name("spell", 18243) == "Nightfin Soup")
assert(ns.catalog.stats().recipes == 1)
print("catalog runtime tests passed")
