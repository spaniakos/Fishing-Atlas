-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
C_Map = {
  GetBestMapForUnit = function() end,
  GetPlayerMapPosition = function() end,
}
C_Item = {GetItemInfo = function() end, GetItemCount = function() end}
C_Spell = {GetSpellInfo = function() end}
SetOverrideBindingClick = function() end
ClearOverrideBindings = function() end
assert(loadfile("FishingAtlas/Core/Diagnostics.lua"))("FishingAtlas", ns)
local r = ns.diagnostics.report()
assert(r.targetMatch and r.mapAPI and r.itemAPI and r.spellAPI and r.bagAPI and r.secureCast)
assert(r.clientIsNewer and not r.dataBuildMatch and r.dataBuild == "70888")
assert(r.tomtom == false and r.gameMap == false)
GetBuildInfo = function() return "1.60.1", "70888", "Nov 9 2026", 16001 end
local original = ns.diagnostics.report()
assert(original.targetMatch and original.dataBuildMatch and not original.clientIsNewer)
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 17000 end
assert(ns.diagnostics.report().targetMatch == false)
print("diagnostics modern API tests passed")
