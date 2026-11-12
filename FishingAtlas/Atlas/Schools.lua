-- SPDX-License-Identifier: GPL-3.0-or-later
-- Recorded school *proximity* observations only: these are PLAYER coordinates, never object spawn coordinates.
local _, ns = ...
ns.schools = {}
local S = ns.schools
local MAX_RECORDS, MERGE = 3000, 0.003

function S.record(mapID, x, y, label)
  local db = ns.storage.db
  if not db or type(db.schoolCandidates) ~= "table" then return nil, "School storage unavailable" end
  if type(mapID) ~= "number" or mapID < 1
    or not ns.util.validCoordinate(x) or not ns.util.validCoordinate(y) then
    return nil, "Invalid player coordinates"
  end
  label = ns.util.safeText(label)
  if label == "Fishing spot" then return nil, "Specify the visible school name" end
  local now = type(time) == "function" and time() or 0
  for _, rec in ipairs(db.schoolCandidates) do
    if type(rec) == "table" and rec.mapID == mapID and rec.label == label
      and ns.util.validCoordinate(rec.x) and ns.util.validCoordinate(rec.y)
      and math.abs(rec.x - x) <= MERGE
      and math.abs(rec.y - y) <= MERGE then
      rec.lastSeen = now
      rec.sightings = (rec.sightings or 1) + 1
      return rec, false
    end
  end
  if #db.schoolCandidates >= MAX_RECORDS then return nil, "School observation storage is full" end
  local rec = {
    id = "candidate:" .. ns.util.gridKey(mapID, x, y) .. ":" .. (#db.schoolCandidates + 1),
    mapID = mapID, x = x, y = y, label = label, sightings = 1,
    firstSeen = now, lastSeen = now, source = "manual_school_sighting",
    precision = "player_position_near_school", verifiedSpawn = false
  }
  db.schoolCandidates[#db.schoolCandidates + 1] = rec
  return rec, true
end

function S.inZone(mapID)
  local output = {}
  for _, rec in ipairs((ns.storage.db and ns.storage.db.schoolCandidates) or {}) do
    if type(rec) == "table" and rec.mapID == mapID and ns.util.validCoordinate(rec.x)
      and ns.util.validCoordinate(rec.y) then output[#output + 1] = rec end
  end
  return output
end

function S.total()
  return #((ns.storage.db and ns.storage.db.schoolCandidates) or {})
end

function S.latest()
  local newest
  for _, rec in ipairs((ns.storage.db and ns.storage.db.schoolCandidates) or {}) do
    if not newest or (rec.lastSeen or 0) >= (newest.lastSeen or 0) then newest = rec end
  end
  return newest
end
