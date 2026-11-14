-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.nearby = {}
local N = ns.nearby
local elapsed, lastAlerts = 0, {}
local CHECK_INTERVAL, ALERT_COOLDOWN = 5, 300

-- Map-relative distances are NOT yards; use normalized [0,1] coordinates.
function N.distanceSquared(x1, y1, x2, y2)
  if not ns.util.validCoordinate(x1) or not ns.util.validCoordinate(y1)
      or not ns.util.validCoordinate(x2) or not ns.util.validCoordinate(y2) then return nil end
  return (x1 - x2) ^ 2 + (y1 - y2) ^ 2
end

function N.find(mapID, x, y, radiusPercent)
  local found = {}
  local r = (tonumber(radiusPercent) or 1) / 100
  if r <= 0 or r > 0.05 then return found end
  for _, node in ipairs(ns.storage.inZone(mapID)) do
    local distance = N.distanceSquared(x, y, node.x, node.y)
    if distance and distance <= r * r then
      found[#found + 1] = { node = node, distance = distance }
    end
  end
  table.sort(found, function(a, b) return a.distance < b.distance end)
  return found
end

-- Historical school sightings are player positions, never guaranteed active pools.
function N.findSchools(mapID, x, y, radiusPercent)
  local found = {}
  local r = (tonumber(radiusPercent) or 1) / 100
  if r <= 0 or r > 0.05 or not ns.schools then return found end
  for _, node in ipairs(ns.schools.inZone(mapID)) do
    local distance = N.distanceSquared(x, y, node.x, node.y)
    if distance and distance <= r * r then
      found[#found + 1] = {node = node, distance = distance}
    end
  end
  table.sort(found, function(a, b) return a.distance < b.distance end)
  return found
end

function N.shouldAlert(id, now)
  if type(id) ~= "string" or type(now) ~= "number" then return false end
  if lastAlerts[id] and now - lastAlerts[id] < ALERT_COOLDOWN then return false end
  lastAlerts[id] = now
  return true
end

function N.scan()
  local db = ns.storage.db
  if not db or not db.settings
    or (not db.settings.notifications and not db.settings.schoolAlerts) then return end
  if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function"
      or type(C_Map.GetPlayerMapPosition) ~= "function" then return end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return end
  local p = C_Map.GetPlayerMapPosition(mapID, "player")
  if not p or type(p.GetXY) ~= "function" then return end
  local x, y = p:GetXY()
  if not ns.util.validCoordinate(x) or not ns.util.validCoordinate(y) then return end
  local now = type(GetTime) == "function" and GetTime() or 0
  if db.settings.notifications then
    local matches = N.find(mapID, x, y, db.settings.radiusPercent or 1)
    local closest = matches[1] and matches[1].node
    if closest and N.shouldAlert("spot:" .. closest.id, now) then
      ns.commands.say("Near saved fishing position: " .. (closest.label or "Spot") ..
        " (historical observation; school activity unknown)")
      if type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.TELL_MESSAGE then
        PlaySound(SOUNDKIT.TELL_MESSAGE)
      end
    end
  end
  if db.settings.schoolAlerts then
    local matches = N.findSchools(mapID, x, y, db.settings.radiusPercent or 1)
    local closest = matches[1] and matches[1].node
    if closest and N.shouldAlert("school:" .. closest.id, now) then
      ns.commands.say("Near a previously sighted school: " ..
        (closest.label or "School") .. " (historical, NOT confirmed active)")
      if type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.TELL_MESSAGE then
        PlaySound(SOUNDKIT.TELL_MESSAGE)
      end
    end
  end
end

function N.start()
  if type(CreateFrame) ~= "function" then return end
  if N.frame then return end
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed >= CHECK_INTERVAL then elapsed = 0; N.scan() end
  end)
  N.frame = frame
end
