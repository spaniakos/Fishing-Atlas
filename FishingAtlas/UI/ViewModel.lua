-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure, provenance-aware explorer presentation model for the v0.99.5 three-panel UI.
local _, ns = ...
ns.viewModel = {}
local V = ns.viewModel
local B = ns.browser
local maxRows = 80

local function nameFor(id)
  return ns.catalog.name("item", id)
end

local function textRow(title, detail, icon, confidence, target)
  local row = {title = tostring(title or ""), detail = tostring(detail or ""),
    icon = icon, confidence = confidence}
  if type(target) == "table" then
    for key, value in pairs(target) do row[key] = value end
  end
  return row
end

local function findZone(mapID)
  for _, zone in ipairs(ns.catalog.zones()) do
    if zone.mapId == mapID then return zone end
  end
  return nil
end

local function validPlace(rec)
  return type(rec) == "table" and type(rec.mapID) == "number"
    and ns.util.validCoordinate(rec.x) and ns.util.validCoordinate(rec.y)
end

function V.zoneVendors(mapID)
  local results = {}
  for _, vendor in ipairs(ns.data.referenceVendors or {}) do
    for _, position in ipairs(vendor.spots or {}) do
      if position.mapID == mapID and ns.util.validCoordinate(position.x)
          and ns.util.validCoordinate(position.y) then
        results[#results + 1] = {id = vendor.id, name = vendor.name,
          x = position.x, y = position.y, mapID = mapID,
          source = "mixed_source_reference", kind = "vendor"}
        break
      end
    end
  end
  table.sort(results, function(a, b) return a.name < b.name end)
  return results
end

function V.fishZones(fishID)
  local zones = {}
  for mapID, fish in pairs(ns.data.referenceZoneFish or {}) do
    for _, record in ipairs(fish) do
      local id = type(record) == "table" and record.id or record
      if id == fishID then
        local zone = findZone(mapID)
        zones[#zones + 1] = {
          mapID = mapID,
          name = zone and zone.name or "Map " .. mapID,
          evidence = type(record) == "table" and record.evidence or "reference"
        }
        break
      end
    end
  end
  table.sort(zones, function(a, b) return a.name < b.name end)
  return zones
end

function V.recordedLocations(mapID)
  local results = {}
  for _, spot in ipairs((ns.storage.db and ns.storage.db.observations) or {}) do
    if validPlace(spot) and spot.mapID == mapID then
      results[#results + 1] = {mapID = mapID, x = spot.x, y = spot.y,
        kind = "position", label = spot.label or "Saved fishing place",
        source = "your_saved_position"}
    end
  end
  for _, school in ipairs((ns.storage.db and ns.storage.db.schoolCandidates) or {}) do
    if validPlace(school) and school.mapID == mapID then
      results[#results + 1] = {mapID = mapID, x = school.x, y = school.y,
        kind = "school", label = school.label or "School proximity",
        source = "your_school_proximity"}
    end
  end
  return results
end

function V.mapPoints(item)
  local results = {}
  if not item then return results end
  local mapID = item.kind == "zone" and item.id or nil
  if item.kind == "vendor_reference" then
    for _, loc in ipairs((item.extra and item.extra.spots) or {}) do
      if validPlace(loc) then
        results[#results + 1] = {mapID = loc.mapID, x = loc.x, y = loc.y,
          kind = "vendor", label = item.name, source = "mixed_source_reference"}
      end
    end
    return results
  elseif item.kind == "fishing_pole" or item.kind == "lure" then
    for _, vendor in ipairs(ns.data.referenceVendors or {}) do
      for _, id in ipairs(vendor.items or {}) do
        if id == item.id then
          for _, place in ipairs(vendor.spots or {}) do
            if validPlace(place) then
              results[#results + 1] = {mapID = place.mapID, x = place.x, y = place.y,
                kind = "vendor", label = vendor.name,
                source = "mixed_source_reference"}
            end
          end
          break
        end
      end
    end
    return results
  elseif item.kind == "merchant_observation" then
    if validPlace(item.extra) then
      local rec = item.extra
      results[1] = {mapID = rec.mapID, x = rec.x, y = rec.y,
        kind = "vendor", label = item.name, source = "client_observed"}
    end
    return results
  elseif item.kind == "school_type" then
    for _, school in ipairs(B.schoolSightings(item.name)) do
      if validPlace(school) then
        results[#results + 1] = {mapID = school.mapID, x = school.x, y = school.y,
          kind = "school", label = school.label, source = "your_school_proximity"}
      end
    end
    return results
  end
  if not mapID then return results end
  for _, loc in ipairs(V.recordedLocations(mapID)) do results[#results + 1] = loc end
  for _, vendor in ipairs(V.zoneVendors(mapID)) do
    results[#results + 1] = vendor
  end
  return results
end

function V.mapID(item)
  if not item then return nil end
  if item.kind == "zone" then return item.id end
  if item.kind == "fish" then
    local zones = V.fishZones(item.id)
    return zones[1] and zones[1].mapID or nil
  end
  local points = V.mapPoints(item)
  return points[1] and points[1].mapID or nil
end

function V.summary(item)
  if not item then return {subtitle = "Choose a record to explore", skill = nil,
      source = "unselected", note = "Browse fish, recipes, zones, schools and vendors."} end
  local summary = {subtitle = item.kind, source = item.confidence, note = ""}
  if item.kind == "zone" then
    local skill = ns.data.zoneFishingSkill and ns.data.zoneFishingSkill[item.id]
    summary.subtitle = "ZONE  |  Map " .. item.id
    summary.skill = skill and skill.minimum or nil
    summary.reliable = skill and skill.reliable or nil
    summary.note = "Zone skill is guide-derived; special waters can differ."
  elseif item.kind == "fish" then
    summary.subtitle = "FISH  |  Item " .. item.id
    summary.note = "Mapped Classic reference catches, not proven server drop rates."
  elseif item.kind == "vendor_reference" then
    summary.subtitle = "VENDOR  |  NPC " .. item.id
    summary.note = "Finddon/ForeverDB reference; check current in-game stock."
  elseif item.kind == "school_type" then
    summary.subtitle = "SCHOOL TYPE"
    summary.note = "Locations are player observations only, not exact pool spawns."
  elseif item.kind == "Cooking" or item.kind == "Fishing" then
    summary.subtitle = "RECIPE  |  Spell " .. item.id
    summary.note = "Client-defined ingredient relationships; acquisition unverified."
  end
  return summary
end

function V.tabs(item)
  if item and item.kind == "zone" then return {"Overview", "Fish", "Schools", "Vendors", "Map"} end
  if item and item.kind == "fish" then return {"Overview", "Zones", "Recipes", "Map"} end
  if item and (item.kind == "fishing_pole" or item.kind == "lure") then
    return {"Overview", "Vendors", "Map"}
  end
  if item and item.kind == "vendor_reference" then return {"Overview", "Goods", "Map"} end
  if item and item.kind == "school_type" then return {"Overview", "Sightings", "Map"} end
  return {"Overview", "Related", "Map"}
end

function V.section(item, section)
  local rows = {}
  if not item then return rows end
  section = section or "Overview"
  local function add(title, detail, icon, confidence, target)
    if #rows < maxRows then
      rows[#rows + 1] = textRow(title, detail, icon, confidence, target)
    end
  end
  if item.kind == "zone" then
    local fish = ns.data.referenceZoneFish and ns.data.referenceZoneFish[item.id] or {}
    local skill = ns.data.zoneFishingSkill and ns.data.zoneFishingSkill[item.id]
    local sightings = B.zoneSightings(item.id)
    local vendors = V.zoneVendors(item.id)
    if section == "Overview" then
      add("Fishing skill", skill and (skill.minimum .. " minimum / " .. skill.reliable .. " reliable")
        or "Not documented", "Interface\\Icons\\Trade_Fishing", "guide_reference")
      if skill and skill.exceptions then
        add("Special water exceptions", skill.exceptions, nil, "guide_reference")
      end
      add("Reference fish", #fish .. " indexed species (not current-server confirmed)",
        "Interface\\Icons\\INV_Misc_Fish_02", "cmangos_reference")
      add("School sightings", #sightings.schools .. " player-recorded positions",
        "Interface\\Icons\\INV_Misc_Spyglass_03", "user_observation")
      add("Vendor references", #vendors .. " mapped NPCs", "Interface\\Icons\\INV_Misc_Bag_10",
        "mixed_source_reference")
    elseif section == "Fish" then
      for _, rec in ipairs(fish) do
        local id = type(rec) == "table" and rec.id or rec
        local evidence = type(rec) == "table" and rec.evidence or "reference"
        add(nameFor(id), "Item " .. id .. " | " .. evidence,
          ns.catalog.icon("item", id), evidence, {itemId = id})
      end
    elseif section == "Schools" then
      for _, school in ipairs(sightings.schools) do
        add(school.label or "School proximity",
          string.format("Player: %.1f, %.1f | %d sightings", school.x * 100,
            school.y * 100, school.sightings or 1), nil, "user_observation")
      end
    elseif section == "Vendors" then
      for _, vendor in ipairs(vendors) do
        add(vendor.name, string.format("Reference location: %.1f, %.1f",
          vendor.x * 100, vendor.y * 100), "Interface\\Icons\\INV_Misc_Bag_10", vendor.source,
          {vendorId = vendor.id, mapID = vendor.mapID, x = vendor.x, y = vendor.y})
      end
    elseif section == "Map" then
      add("Map pins", #V.mapPoints(item) .. " saved/reference positions",
        "Interface\\Icons\\INV_Misc_Map_01", "mixed_sources")
    end
  elseif item.kind == "fish" then
    local places = V.fishZones(item.id)
    if section == "Overview" then
      add("Item ID", item.id, ns.catalog.icon("item", item.id), item.confidence)
      add("Reference zones", #places .. " zone-water relationships", nil, "mixed_sources")
      add("Live drop rates", "Not verified; no estimates supplied", nil, "unknown")
    elseif section == "Zones" or section == "Map" then
      for _, place in ipairs(places) do
        add(place.name, "Map " .. place.mapID .. " | " .. place.evidence, nil, place.evidence)
      end
    elseif section == "Recipes" then
      for _, r in ipairs(ns.catalog.recipeList()) do
        for _, ing in ipairs(r.ingredients or {}) do
          if ing.itemId == item.id then
            add(ns.catalog.name("spell", r.spellId),
              ing.amount .. " x ingredient | Spell " .. r.spellId,
              r.outputItemId and ns.catalog.icon("item", r.outputItemId), "verified_client")
          end
        end
      end
    end
  elseif item.kind == "vendor_reference" then
    local vendor = item.extra or {}
    if section == "Overview" then
      add("Faction", vendor.side or "Unknown",
        vendor.side == "Alliance" and "Interface\\Icons\\INV_BannerPVP_02"
          or vendor.side == "Horde" and "Interface\\Icons\\INV_BannerPVP_01"
          or "Interface\\Icons\\INV_Misc_Map_01", "mixed_source_reference")
      add("Role", vendor.trainer and "Fishing trainer" or (vendor.title or "Merchant"),
        nil, "mixed_source_reference")
      add("Locations", #(vendor.spots or {}) .. " reference NPC coordinates",
        nil, "mixed_source_reference")
      add("Reported goods", #(vendor.items or {}) .. " candidate items", nil,
        "mixed_source_reference")
    elseif section == "Goods" then
      for _, id in ipairs(vendor.items or {}) do
        add(nameFor(id), "Item " .. id .. " | stock unverified",
          ns.catalog.icon("item", id), "mixed_source_reference", {itemId = id})
      end
    elseif section == "Map" then
      for _, place in ipairs(vendor.spots or {}) do
        add("Map " .. place.mapID, string.format("%.1f, %.1f | reference NPC position",
          place.x * 100, place.y * 100), "Interface\\Icons\\INV_Misc_Map_01",
          "mixed_source_reference", {mapID = place.mapID, x = place.x, y = place.y})
      end
    end
  elseif item.kind == "school_type" then
    local places = B.schoolSightings(item.name)
    if section == "Overview" then
      add("School type", item.name, "Interface\\Icons\\Trade_Fishing", "classic_reference")
      add("Your sightings", #places .. " nearby player positions",
        "Interface\\Icons\\INV_Misc_Spyglass_03", "user_observation")
      local seen = {}
      for _, place in ipairs(places) do seen[place.mapID] = true end
      local zoneNames = {}
      for mapID in pairs(seen) do
        local zone = findZone(mapID)
        zoneNames[#zoneNames + 1] = zone and zone.name or ("Map " .. mapID)
      end
      table.sort(zoneNames)
      add("Observed zones", #zoneNames > 0 and table.concat(zoneNames, ", ")
        or "No player-confirmed areas recorded", "Interface\\Icons\\INV_Misc_Map_01",
        "user_observation")
    else
      for _, place in ipairs(places) do
        local zone = findZone(place.mapID)
        add(zone and zone.name or ("Map " .. place.mapID),
          string.format("Nearby observation: %.1f, %.1f",
          place.x * 100, place.y * 100), "Interface\\Icons\\INV_Misc_Map_01",
          "user_observation", {mapID = place.mapID, x = place.x, y = place.y})
      end
    end
  elseif item.kind == "fishing_pole" or item.kind == "lure" then
    if section == "Overview" then
      add("Equipment", item.kind == "lure" and "Fishing lure" or "Fishing pole",
        ns.catalog.icon("item", item.id), item.confidence)
      add("Acquisition", "Source-indexed vendor candidates only; confirm stock",
        nil, "mixed_source_reference")
    else
      for _, vendor in ipairs(ns.data.referenceVendors or {}) do
        for _, id in ipairs(vendor.items or {}) do
          if id == item.id then
            add(vendor.name, (vendor.side or "Unknown") .. " | NPC " .. vendor.id,
              "Interface\\Icons\\INV_Misc_Bag_10",
              "mixed_source_reference", {vendorId = vendor.id})
            break
          end
        end
      end
    end
  elseif item.kind == "Cooking" or item.kind == "Fishing" then
    local plan = ns.kitchen.catalogPlan(item.id, 1)
    if plan then
      add("Cooking skill", plan.minimumSkill or "Unknown",
        "Interface\\Icons\\INV_Misc_Note_01", "verified_client")
      local recipe = ns.catalog.recipe(item.id)
      add("Produces", plan.output,
        recipe and recipe.outputItemId and ns.catalog.icon("item", recipe.outputItemId),
        "verified_client", recipe and recipe.outputItemId
          and {itemId = recipe.outputItemId} or nil)
      add("Learn / obtain recipe", "Source not yet verified on Forever",
        "Interface\\Icons\\INV_Misc_Book_09", "unknown")
      for _, ing in ipairs(plan.reagents or {}) do
        add(ing.name, (ing.need or 0) .. " needed | " .. (ing.missing or 0) .. " missing",
          ns.catalog.icon("item", ing.itemId), "verified_client", {itemId = ing.itemId})
      end
    end
  elseif item.kind == "catch" then
    add("Caught", (item.extra and item.extra.count) or 0, nil, "user_observation")
  end
  if #rows == 0 then
    add("No records yet", "Source data or player discoveries are not available for this section.",
      nil, "unknown")
  end
  return rows
end

function V.counts()
  local keys = {"fish", "recipes", "zones", "schools", "vendors", "gear", "journal"}
  local result = {}
  for _, key in ipairs(keys) do result[key] = #B.list(key, "") end
  return result
end
