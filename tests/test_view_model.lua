-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise image-3 presentation model without a WoW runtime.
local ns = {
  data = {
    referenceZoneFish = {[1440] = {{id = 13759, evidence = "cmangos_classic_reference"}},
      [1438] = {{id = 13759, evidence = "player_observed"}}},
    zoneFishingSkill = {[1440] = {minimum = 55, reliable = 150}},
    referenceAcquisition = {[12225] = {{kind = "quest_reward",
      title = "The Family and the Fishing Pole", questId = 1141,
      mapID = 1439, confidence = "classic_reference"}}},
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
  recipeLearning = {
    info = function(id) return {
      requiredSkill = id == 18243 and 250 or id == 2795 and 25 or nil,
      requirementSource = "forever_client_public_reference",
      profession = "Cooking",
      recipeItemId = id == 18243 and 13945 or id == 2795 and 2889 or nil,
      recipeItemName = id == 2795 and "Recipe: Beer Basted Boar Ribs" or nil
    } end,
    sources = function(id)
      if id == 2795 then return {
        {kind = "recipe_item", itemId = 2889, source = "forever_public_reference"},
        {kind = "vendor", label = "Kendor Kabonka", npcId = 340,
          itemId = 2889, mapID = 1453, x = 0.775, y = 0.527,
          source = "classic_vendor_reference"},
        {kind = "quest", label = "Beer Basted Boar Ribs", questId = 384,
          giver = "Ragnar Thunderbrew", mapID = 1426, x = 0.468, y = 0.524,
          source = "classic_quest_reference"}
      } end
      return {}
    end,
    locations = function() return {} end
  },
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
local activePoints = V.mapPoints(zone)
assert(#activePoints == 2 and activePoints[1].kind == "position"
    and activePoints[2].kind == "vendor",
  "Active mode must retain saved places and vendors, never only schools")
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
local pole = {kind = "fishing_pole", id = 12225,
  name = "Blump Family Fishing Pole", confidence = "classic_reference"}
assert(#V.tabs(pole) == 6, "Gear must provide a Quest source tab")
assert(#V.itemQuests(pole.id) == 1)
assert(V.section(pole, "Quest")[1].title == "The Family and the Fishing Pole")
assert(V.section(pole, "Overview")[1].title == "Item Name")
assert(V.section(fish, "Overview")[1].title == "Item Name")
local cooked = {id = 18243, kind = "Cooking", name = "Nightfin Soup"}
local cookingRows = V.section(cooked, "Overview")
assert(cookingRows[1].title == "Recipe knowledge")
assert(cookingRows[3].title == "Required Cooking skill"
  and cookingRows[3].detail == "250",
  "Cooking spell inspector must show the learn requirement, not a scroll or skill=1")
assert(V.section(cooked, "Sources")[1].title == "Learning source unknown")
local ribs = {id = 2795, kind = "Cooking", name = "Beer Basted Boar Ribs"}
local ribsOverview = V.section(ribs, "Overview")
assert(ribsOverview[3].detail == "25" and ribsOverview[7].detail:find(
  "Recipe: Beer Basted Boar Ribs", 1, true),
  "Cooking ability overview must show verified skill and teaching recipe")
local refs = V.section(ribs, "Sources")
assert(#refs == 3 and refs[1].detail:find("2889", 1, true)
  and refs[2].title == "Kendor Kabonka"
  and refs[2].target.sourceMapFirst
  and refs[3].title == "Beer Basted Boar Ribs"
  and refs[3].target.sourceMapFirst,
  "Cooking sources must link scroll, vendor map and quest map independently")
print("image3 view model / gear quest and Cooking acquisition tests passed")
