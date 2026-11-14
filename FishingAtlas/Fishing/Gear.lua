-- SPDX-License-Identifier: GPL-3.0-or-later
-- Preferences are offered only for fishing equipment currently carried or equipped.
-- Choosing a preference never equips gear or uses a consumable without a player click.
local _, ns = ...
ns.gear = {}
local G = ns.gear

local function usableID(value)
  if type(issecretvalue) == "function" then
    local ok, hidden = pcall(issecretvalue, value)
    if not ok or hidden then return nil end
  end
  if type(value) ~= "number" or value < 1 or value ~= math.floor(value) then return nil end
  return value
end

local function bagFunctions()
  if type(C_Container) == "table"
    and type(C_Container.GetContainerNumSlots) == "function"
    and type(C_Container.GetContainerItemID) == "function" then
    return C_Container.GetContainerNumSlots, C_Container.GetContainerItemID
  end
  if type(GetContainerNumSlots) == "function" and type(GetContainerItemID) == "function" then
    return GetContainerNumSlots, GetContainerItemID
  end
end

local function contents()
  local ids = {}
  local slots, itemAt = bagFunctions()
  if slots and itemAt then
    for bag = 0, 4 do
      local ok, count = pcall(slots, bag)
      if ok and type(count) == "number" then
        for slot = 1, math.min(tonumber(count) or 0, 100) do
          local got, id = pcall(itemAt, bag, slot)
          id = got and usableID(id) or nil
          if id then ids[id] = {equipped = false} end
        end
      end
    end
  end
  -- An equipped fishing pole is owned, even when no longer in a bag.
  if type(GetInventoryItemID) == "function" then
    local ok, id = pcall(GetInventoryItemID, "player", 16)
    id = ok and usableID(id) or nil
    if id then ids[id] = {equipped = true} end
  end
  return ids
end

local function recognized(kind, id)
  local entry = ns.catalog and ns.catalog.entity("item", id)
  if entry and entry.category == kind then return true end
  -- The client itself can identify additional poles omitted by our partial catalog.
  -- There is no equally reliable general item-subclass test for all fishing lures.
  if kind == "fishing_pole" then
    local info = type(GetItemInfoInstant) == "function" and GetItemInfoInstant
      or type(C_Item) == "table" and C_Item.GetItemInfoInstant
    if type(info) == "function" then
      local ok, _, _, _, _, _, classID, subClassID = pcall(info, id)
      if ok and classID == 2 and subClassID == 20 then return true end
    end
  end
  return false
end

function G.available(kind)
  if kind ~= "fishing_pole" and kind ~= "lure" then return {} end
  local out = {}
  for id, state in pairs(contents()) do
    if recognized(kind, id) then
      local label = ns.catalog.name("item", id)
      out[#out + 1] = {id = id, name = label, equipped = state.equipped}
    end
  end
  table.sort(out, function(a, b)
    if a.equipped ~= b.equipped then return a.equipped end
    if a.name ~= b.name then return a.name < b.name end
    return a.id < b.id
  end)
  return out
end

function G.isCarried(id)
  id = tonumber(id)
  return id and contents()[id] ~= nil or false
end

function G.set(kind, itemId)
  if kind ~= "fishing_pole" and kind ~= "lure" then return false, "Invalid gear type" end
  itemId = tonumber(itemId)
  if not itemId or itemId < 1 or itemId ~= math.floor(itemId) then return false, "Invalid item ID" end
  if not ns.storage.db then return false, "Storage unavailable" end
  for _, item in ipairs(G.available(kind)) do
    if item.id == itemId then
      ns.storage.db.gearProfile = ns.storage.db.gearProfile or {}
      ns.storage.db.gearProfile[kind] = itemId
      return true, item.name
    end
  end
  return false, "No matching " .. kind .. " item currently in your bags/equipped slot"
end

function G.profile()
  return (ns.storage.db and ns.storage.db.gearProfile) or {}
end
