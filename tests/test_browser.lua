-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {
 data = {schoolTypes={{name="Floating Wreckage"}}, referenceVendors={{id=66,name="Vendor",trainer=false,title="Shop",
    spots={{mapID=1411,x=0.6,y=0.4}},items={6256},side="Horde"}},
 zoneFishingSkill={[1411]={minimum=1,reliable=25}}, referenceZoneFish={[1411]={{id=6303,evidence="classic_reference"}}},
 recipeLearningReferences = {[2795] = {minimumSkill = 25,
   recipeItemId = 2889, recipeItemName = "Recipe: Beer Basted Boar Ribs",
   source = "forever_client_public_reference"}}},
 util = {validCoordinate = function(n) return type(n) == "number" and n >= 0 and n <= 1 end},
 storage = {db = {
  catches = {fish = {name = "Nightfin", count = 8, mapID = 1411}},
  schoolCandidates = {{id = "school-1", label = "Pool", mapID = 1411, x = 0.3, y = 0.5}},
  vendorObservations = {[100] = {items = {13759}, mapID = 1411, x = 0.4, y = 0.5}}
}}, kitchen = {catalogPlan = function()
  return {minimumSkill = 250, output = "Soup", reagents = {{need = 2, name = "Fish", missing = 1}}}
end}}
ns.fishingScope = {
  data = function()
    return {caught = {[13759] = true},
      items = {[6256] = true, [13759] = true, [9000] = true}}
  end,
  vendor = function() return true end,
  item = function() return true end,
}
ns.catalog = {
  entity = function(_, id)
    if id == 13759 then return {id = 13759, category = "fish",
      confidence = "reference"} end
  end,
  itemList = function()
    return {{id = 13759, category = "fish"},
      {id = 6256, category = "fishing_pole"},
      {id = 9000, category = "crafted_output"}}
  end,
  byCategory = function(cat)
    if cat == "fish" then return {{id = 13759, name = "Nightfin", confidence = "reference"}} end
    return {}
  end,
  recipeList = function()
    return {{spellId = 18243, profession = "Cooking", confidence = "verified_client"}}
  end,
  zones = function() return {{mapId = 1411, name = "Durotar", confidence = "verified_client"}} end,
  name = function(kind, id)
    if kind == "item" and id == 13759 then return "Nightfin" end
    return "Spell " .. id
  end,
  icon = function(_, id) return "icon:" .. id end,
  recipe = function() return {outputItemId = 13931} end
}
assert(loadfile("FishingAtlas/UI/Browser.lua"))("FishingAtlas", ns)
assert(#ns.browser.list("fish", "night") == 1)
assert(#ns.browser.list("fish", "") == 1, "Fish means fishing catches, not every item")
assert(#ns.browser.list("items", "") == 3,
  "Items include Cooking teaching scrolls but no duplicate fish catches")
assert(ns.browser.list("items", "2889")[1].name == "Recipe: Beer Basted Boar Ribs")
assert(#ns.browser.list("fish", "other") == 0)
assert(#ns.browser.list("recipes", "18243") == 1)
assert(#ns.browser.list("zones", "") == 1)
assert(#ns.browser.list("journal", "") == 1)
assert(#ns.browser.list("schools", "") == 2)
assert(#ns.browser.list("vendors", "") == 2)
assert(#ns.browser.details(ns.browser.list("recipes", "")[1]) >= 4)
local zone = ns.browser.list("zones", "")[1]
assert(table.concat(ns.browser.details(zone)," "):find("Minimum fishing skill: 1",1,true))
assert(table.concat(ns.browser.details(zone)," "):find("Indicative fish",1,true))
assert(#ns.browser.zoneSightings(1411).schools == 1)
assert(#ns.browser.zoneSightings(1411).catches == 1)
assert(ns.browser.waypoint(ns.browser.list("vendors", "100")[1]).mapID == 1411)
assert(ns.browser.waypoint(ns.browser.list("vendors", "vendor")[1]).label:find("reference"))
assert(ns.browser.waypoint({kind="fishing_pole",id=6256,name="Pole"}).mapID == 1411)
assert(ns.browser.waypoint(zone).mapID == 1411)
assert(ns.browser.waypoint(ns.browser.list("schools", "wreckage")[1]) == nil)
assert(ns.browser.waypoint(ns.browser.list("schools", "pool")[1]).x == 0.3)
print("browser model tests passed")
