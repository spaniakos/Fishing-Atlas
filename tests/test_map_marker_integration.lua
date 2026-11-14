-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise the shared pin model against the real native pin renderer.
local ns = {
  data = {classicSchoolLocations = {}, referenceSchoolLocations = {}},
  storage = {db = {settings = {mapPins = true, schoolMapMode = "active"}},
    inZone = function() return {} end},
  util = {validCoordinate = function(x)
    return type(x) == "number" and x >= 0 and x <= 1
  end},
}
local vendor = {id = 42, kind = "vendor_reference", name = "The Fishmonger"}
local location = {mapID = 1413, x = 0.32, y = 0.44, label = "The Fishmonger",
  kind = "vendor", source = "mixed_source_reference"}
ns.viewModel = {mapPoints = function()
  return {location}
end}
ns.ui = {selected = function() return vendor end}
ns.liveSchools = {inZone = function() return {} end}
assert(loadfile("FishingAtlas/Atlas/MapMarkers.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Atlas/MapPins.lua"))("FishingAtlas", ns)
local canvas = {
  GetWidth = function() return 500 end,
  GetHeight = function() return 300 end,
}
WorldMapFrame = {IsShown = function() return true end,
  GetMapID = function() return 1413 end,
  ScrollContainer = {Child = canvas}}
local created = {}
CreateFrame = function()
  local f = {}
  f.SetSize = function() end
  f.SetScript = function(self, name, value) self[name] = value end
  f.SetParent = function(self, parent) self.parent = parent end
  f.ClearAllPoints = function() end
  f.SetPoint = function(self, _, _, _, x, y) self.x, self.y = x, y end
  f.CreateTexture = function()
    return {SetAllPoints = function() end, SetTexture = function() end,
      SetVertexColor = function() end}
  end
  f.Show = function(self) self.shown = true end
  f.Hide = function(self) self.shown = false end
  created[#created + 1] = f
  return f
end

local points = ns.mapPins.points(1413)
assert(#points == 1 and points[1].kind == "vendor")
assert(ns.mapPins.refresh())
assert(created[1].shown and created[1].x == 160 and created[1].y == -132)
-- Position changes with the SAME number of pins must invalidate the cache.
location = {mapID = 1413, x = 0.61, y = 0.24, label = "The Fishmonger",
  kind = "vendor", source = "mixed_source_reference"}
assert(ns.mapPins.refresh())
assert(created[1].x == 305 and created[1].y == -72,
  "Same-count coordinate updates must move native pins")
ns.ui.selectedPoint = {mapID = 1413, x = 0.7, y = 0.8,
  label = "Selected merchant", source = "manual_navigation"}
assert(ns.mapPins.points(1413)[1].isSelected,
  "Explicitly selected map point has first priority")
assert(ns.mapPins.refresh())
assert(created[1].x == 350 and created[1].y == -240)
ns.storage.db.settings.schoolMapMode = "probable"
assert(ns.mapPins.refresh())
local all = ns.mapPins.points(1413)
assert(all[1].isSelected and #all == 2,
  "Changing school visibility must preserve vendor and selected point")
ns.storage.db.settings.mapPins = false
assert(not ns.mapPins.refresh() and not created[1].shown,
  "Map pin preference must hide pins immediately")
ns.storage.db.settings.mapPins = true
assert(ns.mapPins.refresh() and created[1].shown)
local otherCanvas = {GetWidth = function() return 300 end,
  GetHeight = function() return 200 end}
WorldMapFrame.ScrollContainer.Child = otherCanvas
assert(ns.mapPins.refresh() and created[1].x == 210
  and created[1].y == -160 and created[1].parent == otherCanvas,
  "New native map canvases must never retain old anchor geometry")
print("selected native vendor pins, coordinate cache, mode and canvas tests passed")
