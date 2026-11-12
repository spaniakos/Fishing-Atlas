-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
local commands = {}
ns.commands = commands

local function say(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff22bb99Fishing Atlas|r: " .. tostring(message))
  end
end
commands.say = say

local function location()
  if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
    return nil, "This client does not expose the required map API"
  end
  local mapID = C_Map.GetBestMapForUnit("player")
  if not mapID then return nil, "No current map found" end
  local p = C_Map.GetPlayerMapPosition(mapID, "player")
  if not p or not p.GetXY then return nil, "Player map coordinates unavailable" end
  local x, y = p:GetXY()
  if not ns.util.validCoordinate(x) or not ns.util.validCoordinate(y) then return nil, "Invalid coordinates" end
  return mapID, x, y
end

function commands.run(raw)
  local command, rest = (raw or ""):match("^%s*(%S*)%s*(.-)%s*$")
  command = (command or ""):lower()
  if command == "add" then
    local mapID, x, y = location()
    if not mapID then say(x); return end
    local node, created = ns.storage.add(mapID, x, y, rest, "manual")
    if not node then say(created); return end
    local status = created and "Saved" or "Updated"
    say(status .. " player-position observation: " .. node.label ..
      string.format(" (%.1f, %.1f)", x * 100, y * 100))
  elseif command == "nearby" then
    local mapID, err = location()
    if not mapID then say(err); return end
    local records = ns.storage.inZone(mapID)
    say(#records .. " stored historical observations in this zone (not confirmed active pools)")
    for i = 1, math.min(#records, 10) do
      local n = records[i]
      say(string.format("%s: %.1f, %.1f (%d sightings)",
        n.label or "Spot", (n.x or 0) * 100, (n.y or 0) * 100, n.sightings or 1))
    end
  elseif command == "stats" then
    say(ns.storage.count() .. " observations saved account-wide")
  elseif command == "list" then
    for _, fish in ipairs(ns.data.fish or {}) do say(fish.name .. " (" .. fish.confidence .. ")") end
  elseif command == "fishing" then
    local _, message = ns.fishing.setEnabled(rest == "on")
    say(message)
  elseif command == "notify" then
    if rest == "on" or rest == "off" then
      ns.storage.db.settings.notifications = rest == "on"
      say("Notifications " .. rest)
    else say("Use: /fa notify on|off") end
  elseif command == "waypoint" then
    local node = ns.storage.latest()
    if not node then say("No observations yet"); return end
    if TomTom and type(TomTom.AddWaypoint) == "function" then
      local opts = { title = "Fishing Atlas: " .. (node.label or "Spot"), persistent = false }
      local ok = pcall(TomTom.AddWaypoint, TomTom, node.mapID, node.x, node.y, opts)
      if ok then say("TomTom waypoint created"); return end
    end
    say("TomTom is unavailable or rejected this waypoint")
  else
    say("Commands: /fa add [label], nearby, list, stats, waypoint, notify on|off, fishing on|off")
  end
end
