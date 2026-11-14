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
assert(loadfile("FishingAtlas/Atlas/MapMarkers.lua"))("FishingAtlas", ns)
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
local ok, added = L.recordVisible("Firefin Snapper School", 1413, 0.423, 0.535)
assert(ok and added == false and #P.points(1413) == 1,
  "Small player movements cannot multiply one school into fake sightings")
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
-- Forever build 70938 can hand an addon a protected/secret tooltip string.
-- The test runtime cannot model secret values, so simulate the exact rejected
-- string-method access with a getter that throws the client's error text.
clock = clock + 61
GameTooltipTextLeft1.GetText = function()
  error("attempt to index local 'value' (a secret string value)")
end
local protected, result = pcall(L.scan)
assert(protected and result == 0, "A secret tooltip may never crash manual scanning")
assert((L.blockedTooltipReads or 0) >= 1)
local update
CreateFrame = function()
  return {SetScript = function(_, event, callback)
    if event == "OnUpdate" then update = callback end
  end}
end
L.start()
assert(type(update) == "function")
assert(pcall(update, {}, 0.5), "A secret tooltip may never crash OnUpdate")
local mapUpdates, pinUpdates = 0, 0
ns.ui = {refreshMap = function() mapUpdates = mapUpdates + 1 end}
ns.mapPins.refresh = function() pinUpdates = pinUpdates + 1 end
GameTooltipTextLeft1.GetText = function() return "Firefin Snapper School" end
local beforeRevision = L.revision
assert(pcall(update, {}, 0.5) and L.revision > beforeRevision,
  "Passive observation must run without clicking Scan now")
assert(mapUpdates == 1 and pinUpdates == 1,
  "A new sighting must update custom and native map pins")
assert(pcall(update, {}, 0.5) and mapUpdates == 1,
  "Repeated sightings must not cause a redraw every scan")
GameTooltip.IsShown = function() return false end
clock = clock + 61
assert(pcall(update, {}, 0.5) and mapUpdates == 2 and pinUpdates == 2,
  "Expired sightings must remove stale map pins")
print("active school modes, passive refresh, dedupe and secret tooltip tests passed")
