-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.routes = {}
local R = ns.routes
function R.plan(mapID, x, y, term)
  if type(mapID) ~= "number" or not ns.util.validCoordinate(x)
    or not ns.util.validCoordinate(y) then return {} end
  term = type(term) == "string" and term:lower() or ""
  local route = {}
  for _, node in ipairs(ns.storage.inZone(mapID)) do
    if type(node.label) == "string" and node.label:lower():find(term, 1, true)
      and ns.util.validCoordinate(node.x) and ns.util.validCoordinate(node.y) then
      local dx, dy = node.x - x, node.y - y
      route[#route + 1] = {node = node, distance = dx * dx + dy * dy}
    end
  end
  table.sort(route, function(a, b)
    if a.distance == b.distance then return a.node.id < b.node.id end
    return a.distance < b.distance
  end)
  return route
end
