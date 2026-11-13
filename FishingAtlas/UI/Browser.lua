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
  if category == "fish" or category == "gear" then
    local kinds = category == "fish" and {"fish"} or {"fishing_pole", "lure"}
    for _, kind in ipairs(kinds) do
      for _, e in ipairs(ns.catalog.byCategory(kind, 200)) do
        push(out, row(e.id, e.name, kind, e.confidence), term)
      end
    end
  elseif category == "recipes" then
    for _, r in ipairs(ns.catalog.recipeList()) do
      push(out, row(r.spellId, ns.catalog.name("spell", r.spellId),
        r.profession or "Cooking", r.confidence, r), term)
    end
  elseif category == "zones" then
    for _, z in ipairs(ns.catalog.zones()) do
      push(out, row(z.mapId, z.name, "zone", z.confidence, z), term)
    end
  elseif category == "schools" then
    local seen = {}
    for _, school in ipairs(ns.data.schoolTypes or {}) do
      seen[school.name:lower()] = true
      push(out, row(school.name, school.name, "school_type", "classic_reference"), term)
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
    for _, vendor in ipairs(ns.data.referenceVendors or {}) do
      push(out, row(vendor.name, vendor.name, "vendor_reference", "forever_guide_reference", vendor), term)
    end
    for id, r in pairs(db.vendorObservations or {}) do
      if type(r) == "table" then
        push(out, row(id, "Merchant NPC #" .. tostring(id),
          "merchant_observation", "client_observed", r), term)
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
    lines[#lines + 1] = "Your recorded school sightings: " .. #rec.schools
    for i = 1, math.min(#rec.schools, 15) do appendPlace(lines, rec.schools[i], "School proximity") end
    lines[#lines + 1] = "Saved fishing positions: " .. #rec.positions
    lines[#lines + 1] = "Zone-tagged catches: " .. #rec.catches
    if #rec.schools == 0 and #rec.positions == 0 and #rec.catches == 0 then
      lines[#lines + 1] = "No verified zone-specific fish or school data yet."
    end
  elseif item.kind == "vendor_reference" then
    local ref = item.extra
    lines[#lines + 1] = "Faction: " .. tostring(ref.side)
    lines[#lines + 1] = "Known area: " .. tostring(ref.area)
    lines[#lines + 1] = "Zone map ID: " .. tostring(ref.mapID)
    lines[#lines + 1] = "Reference vendor goods (not live-verified):"
    for _, itemID in ipairs(ref.items or {}) do
      lines[#lines + 1] = "  " .. ns.catalog.name("item", itemID) .. " [" .. itemID .. "]"
    end
    lines[#lines + 1] = "No confirmed coordinates yet; visit and open merchant to record a position."
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
    lines[#lines + 1] = "Purchase/vendor location: not verified for Forever."
    lines[#lines + 1] = "Do not treat Classic acquisition data as live server stock."
  elseif item.kind == "fish" then
    lines[#lines + 1] = "Known Classic fish ID, but no build-verified drop zones."
    lines[#lines + 1] = "You can record fishing locations manually."
  end
  return lines
end

function B.icon(item)
  if not item then return unknownIcon end
  if item.kind == "fish" or item.kind == "fishing_pole" or item.kind == "lure" then
    return ns.catalog.icon("item", item.id)
  elseif item.kind == "Cooking" or item.kind == "Fishing" then
    local recipe = ns.catalog.recipe(item.id)
    if recipe and recipe.outputItemId then return ns.catalog.icon("item", recipe.outputItemId) end
    return ns.catalog.icon("spell", item.id)
  elseif item.kind == "catch" and item.extra and item.extra.id then
    return ns.catalog.icon("item", item.extra.id)
  end
  return unknownIcon
end

function B.tooltip(item)
  if not item then return nil end
  if item.kind == "fish" or item.kind == "fishing_pole" or item.kind == "lure" then
    return "item", tonumber(item.id)
  elseif item.kind == "Cooking" or item.kind == "Fishing" then
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
  elseif item.kind == "merchant_observation" and item.extra then
    local e = item.extra
    if type(e.mapID) == "number" then candidate = e end
  end
  if candidate and type(candidate.mapID) == "number"
      and ns.util.validCoordinate(candidate.x) and ns.util.validCoordinate(candidate.y) then
    return {mapID = candidate.mapID, x = candidate.x, y = candidate.y,
      label = tostring(candidate.label or item.name) .. " (historical player position)"}
  end
  return nil
end
