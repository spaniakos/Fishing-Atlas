-- SPDX-License-Identifier: GPL-3.0-or-later
local clock = 500
GetTime = function() return clock end
local ns = {data = {schoolTypes = {{name = "Firefin Snapper School"}},
  referenceSchoolLocations = {["Firefin Snapper School"] =
    {{mapID = 1413, x = 0.4, y = 0.5, source = "guide_reference"}}}},
  storage = {db = {settings = {schoolMapMode = "active"}},
    inZone = function() return {} end},
  schools = {inZone = function() return {} end},
  util = {validCoordinate = function(x)
    return type(x) == "number" and x >= 0 and x <= 1
  end}
}
assert(loadfile("FishingAtlas/Atlas/LiveSchools.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Atlas/MapPins.lua"))("FishingAtlas", ns)
local P, L = ns.mapPins, ns.liveSchools
assert(#P.points(1413) == 0, "Default active must not show historical school pins")
ns.storage.db.settings.schoolMapMode = "probable"
local refs = P.points(1413)
assert(#refs == 1 and refs[1].kind == "school_classic_reference")
assert(refs[1].verifiedSpawn == false)
ns.storage.db.settings.schoolMapMode = "active"
assert(L.recordVisible("Firefin Snapper School", 1413, 0.42, 0.53))
assert(#P.points(1413) == 1 and P.points(1413)[1].kind == "school_live_nearby")
assert(#P.points(1414) == 0)
assert(not L.recordVisible("Unknown object", 1413, 0.42, 0.53))
clock = clock + 121
assert(#P.points(1413) == 0, "Live nearby marker must expire")
assert(#L.inZone(1413) == 0)
GameTooltip = {IsShown = function() return true end,
  GetOwner = function() return WorldFrame end}
WorldFrame = {}
GameTooltipTextLeft1 = {GetText = function() return "Firefin Snapper School" end}
C_Map = {GetBestMapForUnit = function() return 1413 end,
  GetPlayerMapPosition = function() return {x = 0.42, y = 0.53} end}
local found, message = L.scan()
assert(found == 1 and type(message) == "string")
assert(#P.points(1413) == 1)
print("active-only default, probable toggle, visible scan and expiry tests passed")
