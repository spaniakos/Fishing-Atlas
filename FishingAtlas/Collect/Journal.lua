-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.journal = {}
local J = ns.journal
local MAX_DISTINCT = 1000
local function data()
  local db = ns.storage.db
  if not db then return nil end
  if type(db.catches) ~= "table" then db.catches = {} end
  return db.catches
end

function J.record(itemID, name, amount, source)
  local catches = data()
  if not catches then return nil, "Storage unavailable" end
  amount = tonumber(amount)
  if not amount or amount ~= math.floor(amount) or amount < 1 or amount > 200 then
    return nil, "Invalid catch quantity"
  end
  if itemID ~= nil and (type(itemID) ~= "number" or itemID < 1) then
    return nil, "Invalid item ID"
  end
  name = ns.util.safeText(name)
  if name == "Fishing spot" then return nil, "Missing item name" end
  local key = itemID and ("item:" .. itemID) or ("name:" .. name:lower())
  local item = catches[key]
  if not item then
    local distinct = 0
    for _ in pairs(catches) do distinct = distinct + 1 end
    if distinct >= MAX_DISTINCT then return nil, "Journal size limit reached" end
    item = { id = itemID, name = name, count = 0, source = source or "manual" }
    catches[key] = item
  end
  item.count = (item.count or 0) + amount
  if type(time) == "function" then item.lastCaught = time() end
  return item
end

function J.total()
  local total = 0
  for _, entry in pairs(data() or {}) do total = total + (entry.count or 0) end
  return total
end

function J.unique()
  local total = 0
  for _ in pairs(data() or {}) do total = total + 1 end
  return total
end
