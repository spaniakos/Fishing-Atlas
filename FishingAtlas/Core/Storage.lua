-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
local Store = ns.storage
local SCHEMA_VERSION = 1
local MAX_NODES = 4000
local MERGE_DISTANCE = 0.003 -- Map-normalized approximation, not a world-distance claim

local function clock()
  if type(time) == "function" then return time() end
  return 0
end

function Store.init()
  if type(FishingAtlasDB) ~= "table" then FishingAtlasDB = {} end
  local db = FishingAtlasDB
  if type(db.schemaVersion) == "number" and db.schemaVersion > SCHEMA_VERSION then
    return nil, "Saved data was written by a newer Fishing Atlas version"
  end
  if type(db.observations) ~= "table" then db.observations = {} end
  if type(db.settings) ~= "table" then db.settings = {} end
  if db.settings.notifications == nil then db.settings.notifications = true end
  db.schemaVersion = SCHEMA_VERSION
  Store.db = db
  return db
end

local function sameNode(node, mapID, x, y, label)
  return type(node) == "table" and node.mapID == mapID and node.label == label
     and ns.util.validCoordinate(node.x) and ns.util.validCoordinate(node.y)
     and math.abs(node.x - x) <= MERGE_DISTANCE
     and math.abs(node.y - y) <= MERGE_DISTANCE
end

function Store.add(mapID, x, y, label, source)
  local db = Store.db
  if not db then return nil, "Storage not initialized" end
  if type(mapID) ~= "number" or mapID < 1 or not ns.util.validCoordinate(x) or not ns.util.validCoordinate(y) then
    return nil, "Invalid map location"
  end
  label = ns.util.safeText(label)
  local now = clock()
  for _, node in ipairs(db.observations) do
    if sameNode(node, mapID, x, y, label) then
      node.lastSeen = now
      node.sightings = (node.sightings or 1) + 1
      return node, false
    end
  end
  if #db.observations >= MAX_NODES then return nil, "Observation storage limit reached" end
  local node = {
    id = ns.util.gridKey(mapID, x, y) .. ":" .. tostring(#db.observations + 1),
    mapID = mapID, x = x, y = y, label = label,
    source = source or "manual", precision = "player_position",
    firstSeen = now, lastSeen = now, sightings = 1
  }
  table.insert(db.observations, node)
  return node, true
end

function Store.inZone(mapID)
  local out = {}
  if not Store.db then return out end
  for _, node in ipairs(Store.db.observations) do
    if type(node) == "table" and node.mapID == mapID then out[#out + 1] = node end
  end
  return out
end

function Store.latest()
  if not Store.db then return nil end
  local found
  for _, node in ipairs(Store.db.observations) do
    if type(node) == "table" and (not found or (node.lastSeen or 0) >= (found.lastSeen or 0)) then found = node end
  end
  return found
end

function Store.count()
  return Store.db and #Store.db.observations or 0
end
