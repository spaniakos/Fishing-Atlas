-- SPDX-License-Identifier: GPL-3.0-or-later
-- Store intended fishing gear; NEVER swap equipment automatically.
local _, ns = ...
ns.gear = {}
local G = ns.gear

function G.set(kind, itemId)
  if kind ~= "fishing_pole" and kind ~= "lure" then return false, "Invalid gear type" end
  itemId = tonumber(itemId)
  if not itemId or itemId < 1 or itemId ~= math.floor(itemId) then return false, "Invalid item ID" end
  if not ns.storage.db then return false, "Storage unavailable" end
  local entity = ns.catalog.entity("item", itemId)
  if not entity or entity.category ~= kind then return false, "Item not indexed as " .. kind end
  ns.storage.db.gearProfile = ns.storage.db.gearProfile or {}
  ns.storage.db.gearProfile[kind] = itemId
  return true, ns.catalog.name("item", itemId)
end

function G.profile()
  return (ns.storage.db and ns.storage.db.gearProfile) or {}
end
