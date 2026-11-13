-- SPDX-License-Identifier: GPL-3.0-or-later
-- Data model for an evidence-aware fishing explorer. Never present player positions
-- or Classic references as confirmed live Forever spawn coordinates.
local _, ns = ...
ns.browser = {}
local B = ns.browser
local unknownIcon = "Interface\\Icons\\INV_Misc_QuestionMark"

local function row(id, name, kind, confidence, extra)
  return {id = id, name = name, kind = kind, confidence = confidence, extra = extra}
end

local function matches(value, term)
  return term == "" or value.name:lower():find(term, 1, true)
    or tostring(value.id):lower():find(term, 1, true)
end

local function push(out, value, term)
  if matches(value, term) then out[#out + 1] = value end
end

function B.list(category, term)
  term = type(term) == "string" and term:lower() or ""
  local out, db = {}, ns.storage.db or {}
  if category == "items" then
    local seen = {}
    for _, entity in ipairs(ns.catalog.itemList and ns.catalog.itemList() or {}) do
      seen[entity.id] = true
      push(out, row(entity.id, ns.catalog.name("item", entity.id), "item",
        entity.confidence), term)
    end
    local observed = ns.data.everloot or {}
    for id in pairs(observed.itemNames or {}) do
      if not seen[id] then
        seen[id] = true
        push(out, row(id, ns.catalog.name("item", id), "item",
          "observed_confirmed"), term)
      end
    end
    for _, group in ipairs({observed.vendorItems or {}, observed.drops or {},
        observed.fishing or {}, observed.poolItems or {}}) do
      for id in pairs(group) do
        if not seen[id] then
          seen[id] = true
          push(out, row(id, ns.catalog.name("item", id), "item",
            "observed_provisional"), term)
        end
      end
    end
  elseif category == "fish" or category == "gear" then
    local kinds = category == "fish" and {"fish"} or {"fishing_pole", "lure"}
    for _, kind in ipairs(kinds) do
      for _, e in ipairs(ns.catalog.byCategory(kind, 200)) do
        push(out, row(e.id, e.name, kind, e.confidence), term)
      end
    end
  elseif category == "recipes" then
    local seenRecipes = {}
    for _, r in ipairs(ns.catalog.recipeList()) do
      seenRecipes[r.spellId] = true
      push(out, row(r.spellId, ns.catalog.name("spell", r.spellId),
        r.profession or "Cooking", r.confidence, r), term)
    end
    for id, recipe in pairs((ns.data.gameFiles or {}).recipes or {}) do
      if not seenRecipes[id] then
        push(out, row(id, ns.catalog.name("spell", id),
          "gamefile_recipe", "game_files_unconfirmed", recipe), term)
      end
    end
  elseif category == "zones" then
    for _, z in ipairs(ns.catalog.zones()) do
      push(out, row(z.mapId, z.name, "zone", z.confidence, z), term)
    end
  elseif category == "schools" then
    local seen = {}
    for _, school in ipairs(ns.sources and ns.sources.schools() or {}) do
      push(out, row(school.name, school.name, "school_type",
        "observed_provisional"), term)
      seen[school.name:lower()] = true
    end
    for _, school in ipairs(ns.data.schoolTypes or {}) do
      if not seen[school.name:lower()] then
        seen[school.name:lower()] = true
        push(out, row(school.name, school.name, "school_type", "classic_reference"), term)
      end
    end
    for _, sighting in ipairs(db.schoolCandidates or {}) do
      if type(sighting) == "table" and type(sighting.label) == "string"
          and not seen[sighting.label:lower()] then
        push(out, row(sighting.label, sighting.label,
          "school_type", "observed_nearby"), term)
        seen[sighting.label:lower()] = true
      end
    end
  elseif category == "journal" then
    for id, r in pairs(db.catches or {}) do
      if type(r) == "table" then
        push(out, row(id, r.name or tostring(id), "catch", "user_observation", r), term)
      end
    end
  elseif category == "vendors" then
    local seenNpcs = {}
    for _, vendor in ipairs(ns.data.referenceVendors or {}) do
      seenNpcs[vendor.id] = true
      push(out, row(vendor.id, vendor.name, "vendor_reference", "mixed_source_reference", vendor), term)
    end
    for id, r in pairs(db.vendorObservations or {}) do
      if type(r) == "table" then
        seenNpcs[id] = true
        push(out, row(id, r.name or ("Merchant NPC #" .. tostring(id)),
          "merchant_observation", "client_observed", r), term)
      end
    end
    for id, npc in pairs((ns.data.everloot or {}).npcs or {}) do
      if not seenNpcs[id] then
        push(out, row(id, npc.name or ("NPC #" .. id), "observed_npc",
          "observed_provisional", npc), term)
      end
    end
  end
  table.sort(out, function(a, b)
    if a.name == b.name then return tostring(a.id) < tostring(b.id) end
    return a.name < b.name
  end)
  return out
end

function B.schoolSightings(label)
  local found = {}
  for _, rec in ipairs((ns.storage.db and ns.storage.db.schoolCandidates) or {}) do
    if type(rec) == "table" and type(rec.label) == "string"
        and rec.label:lower() == tostring(label):lower()
        and ns.util.validCoordinate(rec.x) and ns.util.validCoordinate(rec.y)
        and type(rec.mapID) == "number" then
      found[#found + 1] = rec
    end
  end
  table.sort(found, function(a, b) return (a.lastSeen or 0) > (b.lastSeen or 0) end)
  return found
end

function B.zoneSightings(mapID)
  local out = {schools = {}, positions = {}, catches = {}}
  for _, sighting in ipairs((ns.storage.db and ns.storage.db.schoolCandidates) or {}) do
    if type(sighting) == "table" and sighting.mapID == mapID then
      out.schools[#out.schools + 1] = sighting
    end
  end
  for _, place in ipairs((ns.storage.db and ns.storage.db.observations) or {}) do
    if type(place) == "table" and place.mapID == mapID then
      out.positions[#out.positions + 1] = place
    end
  end
  -- Catch journal lacks map IDs today; never infer a zone from a fish's name.
  for _, catch in pairs((ns.storage.db and ns.storage.db.catches) or {}) do
    if type(catch) == "table" and catch.mapID == mapID then
      out.catches[#out.catches + 1] = catch
    end
  end
  return out
end

local function appendPlace(lines, sighting, prefix)
  if type(sighting.x) == "number" and type(sighting.y) == "number" then
    lines[#lines + 1] = string.format("%s %s: %.1f, %.1f (map %d)",
      prefix, tostring(sighting.label or sighting.name or "Point"),
      sighting.x * 100, sighting.y * 100, sighting.mapID)
  end
end

function B.details(item)
  if not item then return {"Select a record for details."} end
  local lines = {"Source: " .. tostring(item.confidence)}
  if item.kind == "Cooking" or item.kind == "Fishing" then
    local plan = ns.kitchen.catalogPlan(item.id, 1)
    if plan then
      lines[#lines + 1] = "Requires skill " .. tostring(plan.minimumSkill)
      lines[#lines + 1] = "Produces: " .. plan.output
      for _, i in ipairs(plan.reagents) do
        lines[#lines + 1] = string.format("%d x %s | owned %d | missing %d",
          i.need or 0, i.name or "Unknown", i.owned or 0, i.missing or 0)
      end
      lines[#lines + 1] = "Recipe acquisition/vendor: not yet verified."
    end
  elseif item.kind == "school_type" then
    local matchesByName = B.schoolSightings(item.name)
    lines[#lines + 1] = "Classic reference school type; Forever availability unverified."
    lines[#lines + 1] = "Your sightings near this school: " .. #matchesByName
    for i = 1, math.min(#matchesByName, 12) do
      appendPlace(lines, matchesByName[i], "Nearby")
    end
    if #matchesByName == 0 then
      lines[#lines + 1] = "No recorded locations yet. Use /fa school <name> when observed."
    end
  elseif item.kind == "zone" then
    local skill = ns.data.zoneFishingSkill and ns.data.zoneFishingSkill[item.id]
    if skill then
      lines[#lines + 1] = "Minimum fishing skill: " .. skill.minimum
      lines[#lines + 1] = "Skill for reliable catches: " .. skill.reliable
      if skill.exceptions then lines[#lines + 1] = "Exceptions: " .. skill.exceptions end
      lines[#lines + 1] = "Source: Forever fishing guide (not personally verified)"
    else
      lines[#lines + 1] = "Minimum fishing skill: Unknown"
      lines[#lines + 1] = "Reliable-catch skill: Unknown"
    end
    local rec = B.zoneSightings(item.id)
    local reference = ns.data.referenceZoneFish and ns.data.referenceZoneFish[item.id] or {}
    lines[#lines + 1] = "Indicative fish (Classic-reference, not live verified): " .. #reference
    for _, entry in ipairs(reference) do
      local id = type(entry) == "table" and entry.id or entry
      local evidence = type(entry) == "table" and entry.evidence or "unattributed_reference"
      lines[#lines + 1] = "  " .. ns.catalog.name("item", id) .. " (" .. evidence .. ")"
    end
    lines[#lines + 1] = "Your recorded school sightings: " .. #rec.schools
    for i = 1, math.min(#rec.schools, 15) do appendPlace(lines, rec.schools[i], "School proximity") end
    lines[#lines + 1] = "Saved fishing positions: " .. #rec.positions
    lines[#lines + 1] = "Zone-tagged catches: " .. #rec.catches
    for i = 1, math.min(#rec.catches, 20) do
      lines[#lines + 1] = "Caught: " .. tostring(rec.catches[i].name or "Unknown fish") ..
        " (" .. tostring(rec.catches[i].count or 0) .. " total recorded)"
    end
    if #rec.schools == 0 and #rec.positions == 0 and #rec.catches == 0 then
      lines[#lines + 1] = "No verified zone-specific fish or school data yet."
    end
  elseif item.kind == "vendor_reference" then
    local ref = item.extra
    lines[#lines + 1] = "NPC ID: " .. tostring(ref.id)
    lines[#lines + 1] = "Faction: " .. tostring(ref.side)
    lines[#lines + 1] = "Role: " .. (ref.trainer and "Fishing trainer" or (ref.title or "Vendor"))
    lines[#lines + 1] = "Mapped locations: " .. #(ref.spots or {})
    for i = 1, math.min(5, #(ref.spots or {})) do
      local place = ref.spots[i]
      lines[#lines + 1] = string.format("  Map %d: %.1f, %.1f (reference position)",
        place.mapID, place.x * 100, place.y * 100)
    end
    lines[#lines + 1] = "Reference vendor goods (not live-verified):"
    for _, itemID in ipairs(ref.items or {}) do
      lines[#lines + 1] = "  " .. ns.catalog.name("item", itemID) .. " [" .. itemID .. "]"
    end
    lines[#lines + 1] = "Mixed Classic/ForeverDB reference. Confirm stock and coordinates in game."
  elseif item.kind == "merchant_observation" then
    local rec = item.extra
    lines[#lines + 1] = "Last observed inventory: " .. #(rec.items or {}) .. " item IDs"
    for i = 1, math.min(#(rec.items or {}), 30) do
      local id = rec.items[i]
      lines[#lines + 1] = ns.catalog.name("item", id) .. " [" .. id .. "]"
    end
    lines[#lines + 1] = "Location unknown; stock may have changed."
  elseif item.kind == "catch" then
    lines[#lines + 1] = "Journal total: " .. tostring(item.extra.count or 0)
  elseif item.kind == "fishing_pole" or item.kind == "lure" then
    local found = 0
    for _, v in ipairs(ns.data.referenceVendors or {}) do
      for _, id in ipairs(v.items or {}) do
        if id == item.id then
          found = found + 1
          if found <= 12 then lines[#lines + 1] = v.name .. " (" .. v.side .. ", NPC " .. v.id .. ")" end
          break
        end
      end
    end
    lines[#lines + 1] = "Indexed reference sellers: " .. found
    lines[#lines + 1] = "Mixed CMaNGOS/ForeverDB locations and stock; verify in game."
  elseif item.kind == "fish" then
    lines[#lines + 1] = "Known Classic fish ID, but no build-verified drop zones."
    lines[#lines + 1] = "You can record fishing locations manually."
  end
  return lines
end

function B.icon(item)
  if not item then return unknownIcon end
  if item.kind == "item" or item.kind == "fish" or item.kind == "fishing_pole" or item.kind == "lure" then
    return ns.catalog.icon("item", item.id)
  elseif item.kind == "Cooking" or item.kind == "Fishing"
      or item.kind == "gamefile_recipe" then
    local recipe = ns.catalog.recipe(item.id) or
      ((ns.data.gameFiles or {}).recipes or {})[item.id]
    if recipe and recipe.outputItemId then return ns.catalog.icon("item", recipe.outputItemId) end
    return ns.catalog.icon("spell", item.id)
  elseif item.kind == "catch" and item.extra and item.extra.id then
    return ns.catalog.icon("item", item.extra.id)
  elseif item.kind == "school_type" then
    return "Interface\\Icons\\Trade_Fishing"
  elseif item.kind == "vendor_reference" or item.kind == "merchant_observation"
      or item.kind == "observed_npc" then
    return "Interface\\Icons\\INV_Misc_Bag_10"
  end
  return "Interface\\Icons\\INV_Misc_Note_01"
end

function B.tooltip(item)
  if not item then return nil end
  if item.kind == "item" or item.kind == "fish" or item.kind == "fishing_pole" or item.kind == "lure" then
    return "item", tonumber(item.id)
  elseif item.kind == "Cooking" or item.kind == "Fishing"
      or item.kind == "gamefile_recipe" then
    return "spell", tonumber(item.id)
  end
  return nil
end

-- Context navigation is available only for positions actually recorded, never for
-- invented coordinates, map centers or Classic reference acquisition claims.
function B.waypoint(item)
  if not item then return nil end
  local candidate
  if item.kind == "school_type" then
    candidate = B.schoolSightings(item.name)[1]
  elseif item.kind == "zone" then
    local all = B.zoneSightings(item.id)
    candidate = all.schools[1] or all.positions[1]
  elseif item.kind == "vendor_reference" and item.extra then
    local place = item.extra.spots and item.extra.spots[1]
    if place then
      candidate = {mapID = place.mapID, x = place.x, y = place.y,
        label = item.name .. " (mixed-source reference; verify in game)",
        reference = true}
    end
  elseif item.kind == "fishing_pole" or item.kind == "lure" then
    for _, v in ipairs(ns.data.referenceVendors or {}) do
      for _, id in ipairs(v.items or {}) do
        if id == item.id and v.spots and v.spots[1] then
          local place = v.spots[1]
          candidate = {mapID = place.mapID, x = place.x, y = place.y,
            label = v.name .. " (vendor reference; stock unverified)",
            reference = true}
          break
        end
      end
      if candidate then break end
    end
  elseif item.kind == "observed_npc" and ns.sources then
    local spots = ns.sources.vendorLocations(item.id)
    candidate = spots[1]
  elseif item.kind == "item" and ns.sources then
    for _, seller in ipairs(ns.sources.vendorsForItem(item.id)) do
      local places = ns.sources.vendorLocations(seller.npcId)
      if places[1] then
        candidate = places[1]
        candidate.label = seller.title .. " (observed vendor)"
        break
      end
    end
  elseif item.kind == "merchant_observation" and item.extra then
    local e = item.extra
    if type(e.mapID) == "number" then candidate = e end
  end
  if candidate and type(candidate.mapID) == "number"
      and ns.util.validCoordinate(candidate.x) and ns.util.validCoordinate(candidate.y) then
    return {mapID = candidate.mapID, x = candidate.x, y = candidate.y,
      label = tostring(candidate.label or item.name) ..
        (candidate.reference and "" or " (historical player position)")}
  end
  return nil
end
