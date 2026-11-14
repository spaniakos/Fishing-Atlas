-- SPDX-License-Identifier: GPL-3.0-or-later
-- Short-lived school evidence from the player's *current session*.
-- There is no public Classic/Forever API to enumerate all active gameobjects.
-- We use only a recognised visible world tooltip, and label the map marker as
-- the PLAYER'S nearby position. Never claim exact pool object coordinates.
local _, ns = ...
ns.liveSchools = {}
local L = ns.liveSchools
local observations = {}
local SECONDS = 60
local lastScan = "Not scanned yet"
local monitor
local elapsed = 0

local function now()
  if type(GetTime) == "function" then return GetTime() end
  return 0
end

local function schoolName(value)
  -- Newer Forever builds may return protected/secret tooltip strings. Never
  -- run Lua string methods on them; they are inaccessible to addons.
  if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
  if type(value) ~= "string" then return nil end
  value = value:match("^%s*(.-)%s*$")
  for _, school in ipairs(ns.data.schoolTypes or {}) do
    if value:lower() == school.name:lower() then return school.name end
  end
  return nil
end

local function worldTooltip()
  if not GameTooltip or type(GameTooltip.IsShown) ~= "function"
      or not GameTooltip:IsShown() then return nil end
  if type(GameTooltip.GetOwner) == "function" then
    local owner = GameTooltip:GetOwner()
    if owner and owner ~= WorldFrame and owner ~= UIParent then return nil end
  end
  local line = GameTooltipTextLeft1
  if line and type(line.GetText) == "function" then
    return schoolName(line:GetText())
  end
end

-- All tooltip reads and string processing stay in a protected call. A secret
-- tooltip is not usable evidence of a nearby fishing school.
local function safeWorldTooltip()
  local ok, name = pcall(worldTooltip)
  if ok then return name end
  L.blockedTooltipReads = (L.blockedTooltipReads or 0) + 1
  return nil
end

local function playerPosition()
  if type(C_Map) ~= "table" or type(C_Map.GetBestMapForUnit) ~= "function"
      or type(C_Map.GetPlayerMapPosition) ~= "function" then return end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or type(mapID) ~= "number" then return end
  local got, vector = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not got or not vector then return end
  local safe, x, y = pcall(function()
    local px, py = tonumber(vector.x), tonumber(vector.y)
    if px and py and ns.util.validCoordinate(px)
        and ns.util.validCoordinate(py) then return px, py end
  end)
  if safe and x and y then return mapID, x, y end
end

local function prune()
  local t = now()
  for key, point in pairs(observations) do
    if t < point.seenAt or t - point.seenAt > SECONDS then
      observations[key] = nil
    end
  end
end

function L.inZone(mapID, name)
  prune()
  local out = {}
  for _, point in pairs(observations) do
    if point.mapID == mapID and (not name or point.name == name) then
      out[#out + 1] = point
    end
  end
  table.sort(out, function(a, b) return a.seenAt > b.seenAt end)
  return out
end

function L.recordVisible(name, mapID, x, y)
  local safe, school = pcall(schoolName, name)
  name = safe and school or nil
  if not name or type(mapID) ~= "number"
      or not ns.util.validCoordinate(x) or not ns.util.validCoordinate(y) then
    return false
  end
  prune()
  local key = string.format("%s:%d:%d:%d", name, mapID,
    math.floor(x * 100), math.floor(y * 100))
  observations[key] = {
    mapID = mapID, x = x, y = y,
    name = name, label = name .. " (nearby, recently visible)",
    kind = "school_live_nearby",
    source = "recent_world_tooltip", seenAt = now(),
    verifiedSpawn = false, near = true,
  }
  lastScan = "Seen on world tooltip: " .. name ..
    " (player position; expires after 60 sec)"
  return true
end

function L.scan()
  local visible = safeWorldTooltip()
  if not visible then
    local mapID = playerPosition()
    local recent = mapID and L.inZone(mapID) or {}
    if #recent > 0 then
      lastScan = #recent .. " recently observed nearby schools in this zone. " ..
        "These are approximate player positions, not guaranteed current spawns."
      return #recent, lastScan
    end
    lastScan = "No nearby school detected. Hover a visible school in the " ..
      "world to register it. This client cannot scan all active pools remotely."
    return 0, lastScan
  end
  local mapID, x, y = playerPosition()
  if not mapID then
    lastScan = "School tooltip visible, but client player map coordinates unavailable"
    return 0, lastScan
  end
  local captured = L.recordVisible(visible, mapID, x, y)
  return captured and 1 or 0, lastScan
end

function L.status()
  return lastScan
end

function L.start()
  if monitor or type(CreateFrame) ~= "function" then return end
  monitor = CreateFrame("Frame")
  monitor:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + (dt or 0)
    if elapsed < 0.4 then return end
    elapsed = 0
    local ok = pcall(function()
      local visible = safeWorldTooltip()
      if visible then
        local id, x, y = playerPosition()
        if id then L.recordVisible(visible, id, x, y) end
      end
    end)
    if not ok then L.blockedTooltipReads = (L.blockedTooltipReads or 0) + 1 end
  end)
end
