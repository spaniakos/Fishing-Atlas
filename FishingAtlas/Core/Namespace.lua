-- SPDX-License-Identifier: GPL-3.0-or-later
local addonName, ns = ...
ns = ns or {}
ns.name = addonName or "FishingAtlas"
ns.version = "0.99.2"
ns.storage = ns.storage or {}
ns.data = ns.data or {}
ns.util = ns.util or {}

function ns.util.validCoordinate(n)
  return type(n) == "number" and n == n and n >= 0 and n <= 1
end

function ns.util.gridKey(mapID, x, y)
  if type(mapID) ~= "number" or not ns.util.validCoordinate(x) or not ns.util.validCoordinate(y) then
    return nil
  end
  return string.format("%d:%04d:%04d", mapID, math.floor(x * 10000 + 0.5), math.floor(y * 10000 + 0.5))
end

function ns.util.safeText(s)
  if type(s) ~= "string" then return "Fishing spot" end
  s = s:gsub("[%c|]", " "):sub(1, 80)
  if s:match("^%s*$") then return "Fishing spot" end
  return s
end
