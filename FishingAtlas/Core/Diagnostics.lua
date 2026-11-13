-- SPDX-License-Identifier: GPL-3.0-or-later
-- Read-only smoke diagnostics; does not call protected fishing actions.
local _, ns = ...
ns.diagnostics = {}
local D = ns.diagnostics

function D.report()
  local version, build, buildDate, interface = "unknown", "unknown", "unknown", nil
  if type(GetBuildInfo) == "function" then
    version, build, buildDate, interface = GetBuildInfo()
  end
  local result = {
    version = tostring(version or "unknown"),
    build = tostring(build or "unknown"),
    buildDate = tostring(buildDate or "unknown"),
    interface = interface,
    mapAPI = type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function"
      and type(C_Map.GetPlayerMapPosition) == "function",
    itemAPI = type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function",
    spellAPI = type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function",
    bagAPI = type(C_Item) == "table" and type(C_Item.GetItemCount) == "function",
    gameMap = WorldMapFrame ~= nil,
    secureCast = type(SetOverrideBindingClick) == "function"
      and type(ClearOverrideBindings) == "function",
    tomtom = type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function",
  }
  result.targetMatch = result.version == "1.60.1" and result.interface == 16001
  result.dataBuildMatch = result.build == "70888"
  result.dataBuild = "70888"
  result.clientIsNewer = tonumber(result.build) and tonumber(result.build) > 70888 or false
  return result
end
