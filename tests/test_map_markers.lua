-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {
  data = {classicSchoolLocations = {}, referenceSchoolLocations = {}},
  storage = {db = {settings = {schoolMapMode = "active"}},
    inZone = function()
      return {{mapID = 1413, x = 0.4, y = 0.5,
        label = "River", source = "manual"}}
    end},
  util = {validCoordinate = function(x)
    return type(x) == "number" and x >= 0 and x <= 1
  end},
  liveSchools = {inZone = function()
    return {{mapID = 1413, x = 0.3, y = 0.6,
      kind = "school_live_nearby", name = "Floating Wreckage",
      source = "recent_world_tooltip"}}
  end},
  schools = {inZone = function()
    return {{mapID = 1413, x = 0.2, y = 0.8, label = "Fishing School"}}
  end}
}
local vendor = {kind = "vendor_reference", name = "Vendor"}
local npc = {kind = "observed_npc", name = "Fishing Trainer"}
local item = {kind = "item", name = "Fishing Pole"}
local recipe = {kind = "Cooking", name = "Cooked fish"}
local zone = {kind = "zone", id = 1413}
ns.viewModel = {mapPoints = function(rec)
  if rec == zone then
    return {{mapID = 1413, x = 0.4, y = 0.5,
      label = "River", kind = "position", source = "your_saved_position"},
      {mapID = 1413, x = 0.15, y = 0.25,
        label = "Vendor", kind = "vendor", source = "mixed_source_reference"}}
  end
  if rec == vendor then
    return {{mapID = 1413, x = 0.15, y = 0.25,
      label = "Vendor", kind = "vendor", source = "mixed_source_reference"}}
  end
  if rec == npc or rec == item or rec == recipe then
    return {{mapID = 1413, x = 0.65, y = 0.45,
      label = rec.name, kind = "vendor", source = "observed_provisional"}}
  end
  return {}
end}
assert(loadfile("FishingAtlas/Atlas/MapMarkers.lua"))("FishingAtlas", ns)
local M = ns.mapMarkers
local function find(points, kind, label)
  for _, point in ipairs(points) do
    if point.kind == kind and (not label or point.label == label) then return point end
  end
end
for _, rec in ipairs({vendor, npc, item, recipe}) do
  local points = M.collect(rec, 1413)
  assert(find(points, "vendor", rec.name) or
      (rec == vendor and find(points, "vendor", "Vendor")),
    "Selecting a non-school record must display its precise sourced location")
  assert(find(points, "school_live_nearby"),
    "Active mode must still show recent tooltip schools")
end
local points = M.collect(zone, 1413)
local savedCount = 0
for _, point in ipairs(points) do
  if point.label == "River" then savedCount = savedCount + 1 end
end
assert(savedCount == 1, "Personal saved spots must not appear twice on zone view")
assert(find(points, "vendor", "Vendor"), "Zone view must retain vendors in Active")
assert(not find(points, "school_candidate"), "Historic candidate is not active")
local focus = {mapID = 1413, x = 0.15, y = 0.25,
  label = "Vendor", kind = "vendor", source = "selected_record"}
points = M.collect(vendor, 1413, focus)
assert(points[1].isSelected and points[1].label == "Vendor")
local vendors = 0
for _, point in ipairs(points) do
  if point.label == "Vendor" then vendors = vendors + 1 end
end
assert(vendors == 1, "Clicked location should not create an overlapping second pin")
ns.storage.db.settings.schoolMapMode = "probable"
points = M.collect(vendor, 1413)
assert(find(points, "vendor", "Vendor"), "Probable must keep vendor")
assert(find(points, "school_candidate"), "Probable displays manual school candidate")
assert(not find(points, "school_live_nearby"),
  "Probable mode should not mislabel session-only sightings")
ns.viewModel.mapPoints = function() return {} end
ns.storage.inZone = function() return {} end
points = M.collect({kind = "item", name = "Unlocated item"}, 1413)
assert(not find(points, "vendor"),
  "No exact location means no invented vendor pin")
print("map markers: vendor/NPC/item/recipe, saved dedupe, selection and school filters passed")
