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
    itemAPI = type(GetItemInfo) == "function",
    spellAPI = type(GetSpellInfo) == "function",
    bagAPI = type(GetItemCount) == "function",
    gameMap = WorldMapFrame ~= nil,
    secureCast = type(SetOverrideBindingClick) == "function"
      and type(ClearOverrideBindings) == "function",
    tomtom = type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function",
  }
  result.targetMatch = result.version == "1.60.1.70888" and result.interface == 16001
  return result
end
