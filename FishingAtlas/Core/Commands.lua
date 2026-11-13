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
  if command == "" or command == "ui" then
    if not ns.ui.toggle() then say("Explorer unavailable in this client") end
  elseif command == "issue" or command == "bug" or command == "feedback" then
    ns.issues.open()
  elseif command == "diagnose" then
    local d = ns.diagnostics.report()
    say("Client: " .. d.version .. ", build " .. d.build .. ", interface " .. tostring(d.interface))
    say("Forever interface match: " .. tostring(d.targetMatch) ..
      "; data build 70888 match: " .. tostring(d.dataBuildMatch) ..
      "; map API: " .. tostring(d.mapAPI) .. "; world map: " .. tostring(d.gameMap))
    say("Item: " .. tostring(d.itemAPI) .. "; spell: " .. tostring(d.spellAPI) ..
      "; bags: " .. tostring(d.bagAPI) .. "; secure cast: " .. tostring(d.secureCast) ..
      "; TomTom: " .. tostring(d.tomtom))
  elseif command == "plan" then
    local id, count = rest:match("^(%d+)%s*(%d*)$")
    local plan, err = ns.kitchen.catalogPlan(id, count ~= "" and count or 1)
    if not plan then say(err); return end
    say(plan.name .. " -> " .. plan.output .. " (" .. plan.crafts .. " crafts)")
    for _, ing in ipairs(plan.reagents) do
      say(ing.name .. " [" .. ing.itemId .. "]: need " .. ing.need ..
        ", owned " .. ing.owned .. ", missing " .. ing.missing)
    end
  elseif command == "add" then
    local mapID, x, y = location()
    if not mapID then say(x); return end
    local node, created = ns.storage.add(mapID, x, y, rest, "manual")
    if not node then say(created); return end
    local status = created and "Saved" or "Updated"
    say(status .. " player-position observation: " .. node.label ..
      string.format(" (%.1f, %.1f)", x * 100, y * 100))
  elseif command == "school" then
    local mapID, x, y = location()
    if not mapID then say(x); return end
    local rec, created = ns.schools.record(mapID, x, y, rest)
    if not rec then say(created); return end
    say((created and "Recorded" or "Updated") .. " school proximity: " .. rec.label ..
      " (player coordinates, NOT verified school spawn)")
  elseif command == "schools" then
    local mapID, err = location()
    if not mapID then say(err); return end
    local list = ns.schools.inZone(mapID)
    say(#list .. " manually observed school candidates in current zone")
    for i = 1, math.min(#list, 15) do
      local rec = list[i]
      say(string.format("%s at player %.1f, %.1f (%d sightings)", rec.label,
        rec.x * 100, rec.y * 100, rec.sightings))
    end
  elseif command == "pole" or command == "lure" then
    local kind = command == "pole" and "fishing_pole" or "lure"
    local ok, name = ns.gear.set(kind, rest)
    say(ok and ("Saved preferred " .. command .. ": " .. name .. " (manual equip only)") or name)
  elseif command == "profile" then
    local profile = ns.gear.profile()
    say("Pole: " .. (profile.fishing_pole and ns.catalog.name("item", profile.fishing_pole) or "not selected"))
    say("Lure: " .. (profile.lure and ns.catalog.name("item", profile.lure) or "not selected"))
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
    say(ns.storage.count() .. " ordinary fishing positions, " .. ns.schools.total() .. " school candidates")
  elseif command == "list" then
    for _, fish in ipairs(ns.data.fish or {}) do say(fish.name .. " (" .. fish.confidence .. ")") end
  elseif command == "route" then
    local mapID, x, y = location()
    if not mapID then say(x); return end
    local matches = ns.routes.plan(mapID, x, y, rest)
    say(#matches .. " matching saved positions on this map, nearest first")
    for i = 1, math.min(#matches, 8) do
      local n = matches[i].node
      say(string.format("%s at %.1f, %.1f", n.label, n.x * 100, n.y * 100))
    end
  elseif command == "guide" then
    local results = ns.guides.fishSearch(rest)
    say(#results .. " matching fish entries")
    for i = 1, math.min(#results, 8) do
      local fish = results[i]
      say(fish.name .. " (" .. fish.confidence .. ")")
    end
  elseif command == "caught" then
    local count, name = rest:match("^(%d+)%s+(.+)$")
    name = name or rest
    local item, err = ns.journal.record(nil, name, tonumber(count) or 1, "manual")
    if item then say("Recorded " .. item.count .. " total: " .. item.name) else say(err) end
  elseif command == "collection" then
    say("Collected " .. ns.journal.total() .. " catches across " .. ns.journal.unique() .. " item types")
  elseif command == "catalog" then
    local s = ns.catalog.stats()
    say(string.format("Build 70888: %d items, %d spells, %d recipes (%d cooking, %d fishing)",
      s.items, s.spells, s.recipes, s.cooking, s.fishing))
  elseif command == "find" then
    local matches = ns.catalog.search(rest, nil, nil, 12)
    say(#matches .. " matching imported records (client records are not live spawn verification)")
    for _, item in ipairs(matches) do
      say(item.name .. " [" .. item.kind .. ":" .. item.id .. "] (" .. item.confidence .. ")")
    end
  elseif command == "fish" or command == "gear" then
    local categories = command == "fish" and {"fish"} or {"fishing_pole", "lure"}
    for _, category in ipairs(categories) do
      local found = ns.catalog.byCategory(category, 25)
      say(category .. ": " .. #found .. " reference entries")
      for _, item in ipairs(found) do say(item.name .. " [" .. item.id .. "] (" .. item.confidence .. ")") end
    end
  elseif command == "zones" then
    local found = ns.catalog.zones()
    say(#found .. " map records extracted from build 70888")
    for i = 1, math.min(#found, 10) do
      say(found[i].name .. " [UiMapID " .. found[i].mapId .. "]")
    end
  elseif command == "recipeid" then
    local id = tonumber(rest)
    local recipe = id and ns.catalog.recipe(id) or nil
    if not recipe then say("Unknown recipe spell ID: " .. tostring(rest)); return end
    say(ns.catalog.name("spell", id) .. " [" .. id .. "], " .. tostring(recipe.profession))
    if recipe.outputItemId then
      say("Output: " .. ns.catalog.name("item", recipe.outputItemId) .. " [" .. recipe.outputItemId .. "]")
    end
    for _, item in ipairs(recipe.ingredients or {}) do
      say("  " .. item.amount .. " x " .. ns.catalog.name("item", item.itemId) .. " [" .. item.itemId .. "]")
    end
  elseif command == "recipes" then
    local matches = ns.kitchen.search(rest)
    say(#matches .. " matching cooking recipes (reference data)")
    for i = 1, math.min(12, #matches) do
      local recipe = matches[i]
      say(recipe.name .. " from " .. recipe.sourceText .. " [skill " .. recipe.skill .. "]")
    end
  elseif command == "cook" then
    local recipe = ns.kitchen.get(rest)
    if not recipe then say("Unknown recipe ID; use /fa recipes")
    else
      say(recipe.name .. " -> " .. recipe.output .. " (requires Cooking " .. recipe.skill .. ")")
      for _, ing in ipairs(recipe.ingredients) do say("  " .. ing.amount .. " x " .. ing.name) end
      say("Acquisition: " .. recipe.sourceText)
    end
  elseif command == "radius" then
    local num = tonumber(rest)
    if num and num >= 0.1 and num <= 5 then
      ns.storage.db.settings.radiusPercent = num
      say("Historical observation alert radius: " .. num .. "% of the current map")
    else
      say("Use /fa radius 0.1 through 5 (map percentage, not yards)")
    end
  elseif command == "fishing" then
    local _, message = ns.fishing.setEnabled(rest == "on")
    say(message)
  elseif command == "notify" then
    if rest == "on" or rest == "off" then
      ns.storage.db.settings.notifications = rest == "on"
      say("Notifications " .. rest)
    else say("Use: /fa notify on|off") end
  elseif command == "waypointschool" then
    local node = ns.schools.latest()
    if not node then say("No school candidates saved"); return end
    if TomTom and type(TomTom.AddWaypoint) == "function" then
      local ok = pcall(TomTom.AddWaypoint, TomTom, node.mapID, node.x, node.y,
        {title = "Fishing Atlas: near " .. node.label .. " (unconfirmed)", persistent = false})
      if ok then say("TomTom school-candidate waypoint created"); return end
    end
    say("TomTom is unavailable or rejected this waypoint")
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
    say("Explorer: /fa or /fa ui; Fish-to-Table: /fa plan <spellID> [crafts]; /fa diagnose")
    say("Commands: add [label], school [name], schools, nearby, stats, waypoint, waypointschool")
    say("Also: radius <percent>, fishing on|off, notify on|off, pole <id>, lure <id>, profile")
    say("Journal: caught [quantity] <item name>, collection, guide [fish], route [spot]")
    say("Database: catalog, find <term>, fish, gear, zones, recipeid <spell ID>")
    say("Feedback: /fa issue opens a copyable GitHub Issues URL")
  end
end
