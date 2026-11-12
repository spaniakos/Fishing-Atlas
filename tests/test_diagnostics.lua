-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
GetBuildInfo = function() return "1.60.1.70888", "70888", "Nov 9 2026", 16001 end
C_Map = {
  GetBestMapForUnit = function() end,
  GetPlayerMapPosition = function() end,
}
GetItemInfo = function() end
GetSpellInfo = function() end
GetItemCount = function() end
SetOverrideBindingClick = function() end
ClearOverrideBindings = function() end
assert(loadfile("FishingAtlas/Core/Diagnostics.lua"))("FishingAtlas", ns)
local r = ns.diagnostics.report()
assert(r.targetMatch and r.mapAPI and r.itemAPI and r.spellAPI and r.bagAPI and r.secureCast)
assert(r.tomtom == false and r.gameMap == false)
GetBuildInfo = function() return "1.60.1.70900", "70900", "Nov 20 2026", 16001 end
assert(ns.diagnostics.report().targetMatch == false)
print("diagnostics tests passed")
