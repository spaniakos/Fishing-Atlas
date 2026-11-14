-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise image-3 presentation model without a WoW runtime.
local ns = {
  data = {
    referenceZoneFish = {[1440] = {{id = 13759, evidence = "cmangos_classic_reference"}},
      [1438] = {{id = 13759, evidence = "player_observed"}}},
    zoneFishingSkill = {[1440] = {minimum = 55, reliable = 150}},
    referenceVendors = {{id = 42, name = "Fishing Merchant", side = "Alliance",
      spots = {{mapID = 1440, x = 0.42, y = 0.63}}, items = {6256}}},
  },
  util = {validCoordinate = function(n)
    return type(n) == "number" and n >= 0 and n <= 1
  end},
  storage = {db = {observations = {{mapID = 1440, x = 0.5, y = 0.3, label = "Lake"}},
    schoolCandidates = {{mapID = 1440, x = 0.6, y = 0.4,
      label = "Fishing School", sightings = 2}},
    catches = {}, vendorObservations = {}}},
  kitchen = {catalogPlan = function()
    return {minimumSkill = 150, output = "Cooked fish",
      reagents = {{itemId = 13759, name = "Fish", need = 2, missing = 1}}}
  end}
}
ns.catalog = {
  name = function(_, id) return "Item " .. id end,
  icon = function(_, id) return "icon:" .. id end,
  zones = function() return {{mapId = 1440, name = "Ashenvale"}} end,
  recipe = function() return {outputItemId = 42} end,
  recipeList = function() return {} end,
  byCategory = function() return {} end
}
ns.browser = {
  list = function() return {} end,
  zoneSightings = function()
    return {schools = ns.storage.db.schoolCandidates, positions = ns.storage.db.observations,
      catches = {}}
  end,
  schoolSightings = function()
    return ns.storage.db.schoolCandidates
  end
}
assert(loadfile("FishingAtlas/UI/ViewModel.lua"))("FishingAtlas", ns)
local V = ns.viewModel
local zone = {kind = "zone", id = 1440, name = "Ashenvale", confidence = "verified_client"}
local summary = V.summary(zone)
assert(summary.skill == 55 and summary.reliable == 150)
assert(#V.zoneVendors(1440) == 1)
assert(#V.recordedLocations(1440) == 2)
assert(#V.mapPoints(zone) == 0, "Active-only default must not show historical positions")
ns.storage.db.settings = {schoolMapMode = "probable"}
assert(#V.mapPoints(zone) == 3)
assert(V.mapID(zone) == 1440)
assert(#V.section(zone, "Fish") == 1)
assert(V.section(zone, "Fish")[1].title == "Item 13759")
assert(#V.section(zone, "Schools") == 1)
assert(#V.section(zone, "Vendors") == 1)
assert(V.section(zone, "Overview")[1].title == "Fishing skill")
local fish = {kind = "fish", id = 13759, name = "Nightfin", confidence = "reference"}
assert(#V.fishZones(13759) == 2)
assert(#V.section(fish, "Zones") == 2)
assert(#V.tabs(zone) == 5 and #V.tabs(fish) == 5)
assert(#V.mapPoints({kind = "school_type", name = "Fishing School"}) == 1)
local vendor = {kind = "vendor_reference", name = "Fishing Merchant",
  extra = ns.data.referenceVendors[1]}
assert(#V.section(vendor, "Goods") == 1)
assert(V.mapPoints(vendor)[1].source == "mixed_source_reference")
print("image3 view model tests passed")
