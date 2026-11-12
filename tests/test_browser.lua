-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {storage = {db = {
  catches = {fish = {name = "Nightfin", count = 8}},
  schoolCandidates = {{id = "school-1", label = "Pool", x = 0.3, y = 0.5}},
  vendorObservations = {[100] = {items = {13759}}}
}}, kitchen = {catalogPlan = function()
  return {minimumSkill = 250, output = "Soup", reagents = {{need = 2, name = "Fish", missing = 1}}}
end}}
ns.catalog = {
  byCategory = function(cat)
    if cat == "fish" then return {{id = 13759, name = "Nightfin", confidence = "reference"}} end
    return {}
  end,
  recipeList = function()
    return {{spellId = 18243, profession = "Cooking", confidence = "verified_client"}}
  end,
  zones = function() return {{mapId = 1411, name = "Durotar", confidence = "verified_client"}} end,
  name = function(_, id) return "Spell " .. id end
}
assert(loadfile("FishingAtlas/UI/Browser.lua"))("FishingAtlas", ns)
assert(#ns.browser.list("fish", "night") == 1)
assert(#ns.browser.list("fish", "other") == 0)
assert(#ns.browser.list("recipes", "18243") == 1)
assert(#ns.browser.list("zones", "") == 1)
assert(#ns.browser.list("journal", "") == 1)
assert(#ns.browser.list("schools", "") == 1)
assert(#ns.browser.list("vendors", "") == 1)
assert(#ns.browser.details(ns.browser.list("recipes", "")[1]) >= 4)
print("browser model tests passed")
