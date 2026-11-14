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

local function source() return ns.sources end

local function knownObserved(itemId)
  local info = (ns.data.everloot or {}).itemNames or {}
  return info[itemId] ~= nil
end

local function validPlace(rec)
  return type(rec) == "table" and type(rec.mapID) == "number"
    and ns.util.validCoordinate(rec.x) and ns.util.validCoordinate(rec.y)
end

function V.zoneVendors(mapID)
  local results = {}
  for _, vendor in ipairs(ns.data.referenceVendors or {}) do
    if not ns.fishingScope or ns.fishingScope.vendor(vendor.id) then
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
  end
  local sellerSet = {}
  for itemID, offers in pairs((ns.data.everloot or {}).vendorItems or {}) do
    if not ns.fishingScope or ns.fishingScope.item(itemID) then
      for _, offer in ipairs(offers) do sellerSet[offer.npcId] = true end
    end
  end
  for npcId in pairs(sellerSet) do
    if source() then
      for _, spot in ipairs(source().vendorLocations(npcId)) do
        if spot.mapID == mapID and validPlace(spot) then
          local npc = source().vendor(npcId) or {}
          results[#results + 1] = {id = npcId, name = npc.name or ("NPC " .. npcId),
            x = spot.x, y = spot.y, mapID = mapID,
            source = (spot.installs or 0) >= 3 and "observed_confirmed"
              or "observed_provisional", kind = "vendor"}
        end
      end
    end
  end
  table.sort(results, function(a, b) return a.name < b.name end)
  return results
end

function V.fishZones(fishID)
  local zones = {}
  local seen = {}
  for _, rec in ipairs(source() and source().fishingForItem(fishID) or {}) do
    local zone = findZone(rec.mapID)
    zones[#zones + 1] = {mapID = rec.mapID,
      name = zone and zone.name or ("Map " .. rec.mapID), evidence = rec.confidence,
      installs = rec.installs}
    seen[rec.mapID] = true
  end
  for mapID, fish in pairs(ns.data.referenceZoneFish or {}) do
    for _, record in ipairs(fish) do
      local id = type(record) == "table" and record.id or record
      if id == fishID and not seen[mapID] then
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

function V.itemVendors(itemID)
  local out, seen = {}, {}
  for _, rec in ipairs(source() and source().vendorsForItem(itemID) or {}) do
    out[#out + 1] = {id = rec.npcId, name = rec.title, kind = "vendor",
      confidence = rec.confidence, installs = rec.installs}
    seen[rec.npcId] = true
  end
  for _, vendor in ipairs(ns.data.referenceVendors or {}) do
    if not seen[vendor.id] then
      for _, id in ipairs(vendor.items or {}) do
        if id == itemID then
          out[#out + 1] = {id = vendor.id, name = vendor.name,
            confidence = "mixed_source_reference", kind = "vendor"}
          seen[vendor.id] = true
          break
        end
      end
    end
  end
  for id, vendor in pairs((ns.storage.db and ns.storage.db.vendorObservations) or {}) do
    if not seen[id] then
      for _, good in ipairs(vendor.items or {}) do
        if good == itemID then
          out[#out + 1] = {id = id, name = vendor.name or ("NPC " .. id),
            confidence = "client_observed", kind = "vendor"}
          seen[id] = true
          break
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function V.itemCrafts(itemID)
  local out, seen = {}, {}
  for _, rec in ipairs(source() and source().craftedItem(itemID) or {}) do
    out[#out + 1] = rec
    seen[rec.spellId] = true
  end
  for _, recipe in ipairs(ns.catalog.recipeList()) do
    if recipe.outputItemId == itemID and not seen[recipe.spellId] then
      out[#out + 1] = {kind = "craft", spellId = recipe.spellId,
        title = ns.catalog.name("spell", recipe.spellId),
        confidence = "verified_client"}
    end
  end
  for spellId, recipe in pairs((ns.data.gameFiles or {}).recipes or {}) do
    if recipe.outputItemId == itemID and not seen[spellId] then
      out[#out + 1] = {kind = "craft", spellId = spellId,
        title = ns.catalog.name("spell", spellId),
        confidence = "game_files_unconfirmed"}
      seen[spellId] = true
    end
  end
  for _, rec in ipairs((ns.data.referenceAcquisition or {})[itemID] or {}) do
    if rec.kind == "crafted" then
      out[#out + 1] = {kind = "craft_reference", title = rec.title,
        note = rec.note, spellId = rec.spellId, confidence = rec.confidence,
        sourceUrl = rec.url}
    end
  end
  -- The client relation graph also records profession spells outside Cooking.
  for _, edge in ipairs((ns.data.gameFiles or {}).relations or {}) do
    if edge.fromKind == "item" and edge.fromId == itemID
        and edge.rel == "created_by" and edge.toKind == "spell"
        and not seen[edge.toId] then
      seen[edge.toId] = true
      out[#out + 1] = {kind = "craft", spellId = edge.toId,
        title = ns.catalog.name("spell", edge.toId),
        confidence = "game_files_unconfirmed"}
    end
  end
  return out
end

function V.itemDrops(itemID)
  local out = source() and source().dropsForItem(itemID) or {}
  for _, ref in ipairs((ns.data.referenceAcquisition or {})[itemID] or {}) do
    if ref.kind == "object_loot" or ref.kind == "creature_drop" then
      out[#out + 1] = {kind = ref.kind, title = ref.title, note = ref.note,
        mapID = ref.mapID, confidence = ref.confidence, sourceUrl = ref.url}
    end
  end
  return out
end

function V.itemQuests(itemID)
  local out = {}
  for _, record in ipairs((ns.data.referenceAcquisition or {})[itemID] or {}) do
    if record.kind == "quest_reward" then out[#out + 1] = record end
  end
  return out
end

function V.itemMapPoints(itemID)
  local out, seen = {}, {}
  local function add(place, label, kind, evidence)
    if validPlace(place) then
      local key = tostring(place.mapID) .. ":" .. tostring(place.x) .. ":" .. tostring(place.y)
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = {mapID = place.mapID, x = place.x, y = place.y,
          kind = kind, label = label, source = evidence or "reference"}
      end
    end
  end
  for _, vendor in ipairs(V.itemVendors(itemID)) do
    if source() then
      for _, loc in ipairs(source().vendorLocations(vendor.id)) do
        add(loc, vendor.name .. (loc.near and " (nearby)" or ""),
          "vendor", vendor.confidence)
      end
    end
    for _, ref in ipairs(ns.data.referenceVendors or {}) do
      if ref.id == vendor.id then
        for _, loc in ipairs(ref.spots or {}) do
          add(loc, ref.name .. " (reference)", "vendor", "mixed_source_reference")
        end
      end
    end
  end
  for _, drop in ipairs(V.itemDrops(itemID)) do
    if drop.mapID and validPlace(drop) then
      add(drop, drop.title, "school", drop.confidence)
    elseif drop.npcId and source() then
      for _, loc in ipairs(source().vendorLocations(drop.npcId)) do
        add(loc, drop.title, "npc", drop.confidence)
      end
    end
  end
  return out
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

function V.schoolMapMode()
  return ns.storage and ns.storage.db and ns.storage.db.settings
    and ns.storage.db.settings.schoolMapMode or "active"
end

function V.mapPoints(item)
  local results = {}
  if not item then return results end
  local mapID = item.kind == "zone" and item.id or nil
  -- Do NOT discard vendors, NPCs or saved spots in Active school mode.
  -- Filtering school evidence happens below, not at the record level.
  if item.kind == "item" then
    return V.itemMapPoints(item.id)
  elseif item.kind == "observed_npc" then
    for _, loc in ipairs(source() and source().vendorLocations(item.id) or {}) do
      if validPlace(loc) then
        results[#results + 1] = {mapID = loc.mapID, x = loc.x, y = loc.y,
          kind = "npc", label = item.name, source = "observed_npc",
          near = loc.near}
      end
    end
    return results
  elseif item.kind == "vendor_reference" then
    for _, loc in ipairs((item.extra and item.extra.spots) or {}) do
      if validPlace(loc) then
        results[#results + 1] = {mapID = loc.mapID, x = loc.x, y = loc.y,
          kind = "vendor", label = item.name, source = "mixed_source_reference"}
      end
    end
    return results
  elseif item.kind == "fishing_pole" or item.kind == "lure" then
    return V.itemMapPoints(item.id)
  elseif item.kind == "merchant_observation" then
    if validPlace(item.extra) then
      local rec = item.extra
      results[1] = {mapID = rec.mapID, x = rec.x, y = rec.y,
        kind = "vendor", label = item.name, source = "client_observed"}
    end
    return results
  elseif item.kind == "Cooking" or item.kind == "Fishing"
      or item.kind == "gamefile_recipe" then
    local recipe = ns.catalog.recipe(item.id) or
      ((ns.data.gameFiles or {}).recipes or {})[item.id]
    if recipe and recipe.recipeItemId then
      return V.itemMapPoints(recipe.recipeItemId)
    end
    local out = {}
    for _, trainer in ipairs(source() and source().trainersForRecipe(item.id) or {}) do
      for _, loc in ipairs(source().vendorLocations(trainer.npcId)) do
        if validPlace(loc) then
          out[#out + 1] = {mapID = loc.mapID, x = loc.x, y = loc.y,
            kind = "vendor", label = trainer.title,
            source = trainer.confidence}
        end
      end
    end
    return out
  elseif item.kind == "school_type" then
    if V.schoolMapMode() == "active" then
      local current = type(C_Map) == "table"
        and type(C_Map.GetBestMapForUnit) == "function"
        and C_Map.GetBestMapForUnit("player") or nil
      if ns.liveSchools then
        for _, rec in ipairs(ns.liveSchools.inZone(current, item.name)) do
          results[#results + 1] = rec
        end
      end
      return results
    end
    for _, school in ipairs(source() and source().schoolLocations(item.name) or {}) do
      results[#results + 1] = school
    end
    for _, guide in ipairs((ns.data.classicSchoolLocations or {})[item.name] or {}) do
      if validPlace(guide) then
        results[#results + 1] = {mapID = guide.mapID, x = guide.x, y = guide.y,
          kind = "school_guide", label = item.name .. " (Classic probable)",
          source = "cmangos_classic_reference", objectId = guide.objectId}
      end
    end
    for _, guide in ipairs((ns.data.referenceSchoolLocations or {})[item.name] or {}) do
      if validPlace(guide) then
        results[#results + 1] = {mapID = guide.mapID, x = guide.x, y = guide.y,
          kind = "school_guide", label = item.name .. " (guide reference)",
          source = "guide_reference", url = guide.url}
      end
    end
    for _, school in ipairs(B.schoolSightings(item.name)) do
      if validPlace(school) then
        results[#results + 1] = {mapID = school.mapID, x = school.x, y = school.y,
          kind = "school", label = school.label, source = "your_school_proximity"}
      end
    end
    return results
  end
  if not mapID then return results end
  for _, loc in ipairs(V.recordedLocations(mapID)) do
    if loc.kind ~= "school" or V.schoolMapMode() == "probable" then
      results[#results + 1] = loc
    end
  end
  -- A vendor is still a vendor when the player has seen zero live schools.
  for _, vendor in ipairs(V.zoneVendors(mapID)) do
    results[#results + 1] = vendor
  end
  if V.schoolMapMode() == "active" then
    for _, rec in ipairs(ns.liveSchools and ns.liveSchools.inZone(mapID) or {}) do
      results[#results + 1] = rec
    end
    return results
  end
  for name, spots in pairs(ns.data.classicSchoolLocations or {}) do
    for _, spot in ipairs(spots) do
      if spot.mapID == mapID and validPlace(spot) then
        results[#results + 1] = {mapID = mapID, x = spot.x, y = spot.y,
          kind = "school_guide", label = name .. " (Classic probable)",
          source = "cmangos_classic_reference", objectId = spot.objectId}
      end
    end
  end
  for name, spots in pairs(ns.data.referenceSchoolLocations or {}) do
    for _, spot in ipairs(spots) do
      if spot.mapID == mapID and validPlace(spot) then
        results[#results + 1] = {mapID = mapID, x = spot.x, y = spot.y,
          kind = "school_guide", label = name .. " (guide reference)",
          source = "guide_reference", url = spot.url}
      end
    end
  end
  return results
end

function V.mapID(item)
  if not item then return nil end
  if item.kind == "zone" then return item.id end
  if item.kind == "item" or item.kind == "observed_npc" then
    local points = V.mapPoints(item)
    return points[1] and points[1].mapID or nil
  end
  if item.kind == "fish" then
    local zones = V.fishZones(item.id)
    return zones[1] and zones[1].mapID or nil
  end
  if item.kind == "fishing_pole" or item.kind == "lure" then
    local points = V.itemMapPoints(item.id)
    if points[1] then return points[1].mapID end
    local references = (ns.data.referenceAcquisition or {})[item.id] or {}
    return references[1] and references[1].mapID or nil
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
  elseif item.kind == "item" then
    summary.subtitle = "ITEM  |  ID " .. item.id
    summary.note = knownObserved(item.id) and "Named by independent player observations."
      or "Client/reference item; availability depends on source evidence."
  elseif item.kind == "observed_npc" then
    summary.subtitle = "NPC  |  ID " .. item.id
    summary.note = "Player sightings; interaction coordinates are approximate."
  elseif item.kind == "fish" then
    summary.subtitle = "FISHING CATCH  |  Item " .. item.id
    summary.note = "Mapped Classic reference catches, not proven server drop rates."
  elseif item.kind == "vendor_reference" then
    summary.subtitle = "VENDOR  |  NPC " .. item.id
    summary.note = "Finddon/ForeverDB reference; check current in-game stock."
  elseif item.kind == "school_type" then
    summary.subtitle = "SCHOOL TYPE"
    summary.note = "Guide leads and player positions; neither guarantees active pools."
  elseif item.kind == "Cooking" or item.kind == "Fishing"
      or item.kind == "gamefile_recipe" then
    summary.subtitle = "RECIPE  |  Spell " .. item.id
    summary.note = "Client-defined ingredient relationships; acquisition unverified."
  end
  return summary
end

function V.tabs(item)
  if item and item.kind == "zone" then return {"Overview", "Fish", "Schools", "Vendors", "Map"} end
  if item and item.kind == "item" then
    return {"Overview", "Vendors", "Drops", "Crafted", "Map"}
  end
  if item and item.kind == "observed_npc" then
    return {"Overview", "Drops", "Goods", "Map"}
  end
  if item and (item.kind == "Cooking" or item.kind == "Fishing"
      or item.kind == "gamefile_recipe") then
    return {"Overview", "Ingredients", "Sources", "Map"}
  end
  if item and item.kind == "fish" then
    return {"Overview", "Zones", "Sources", "Recipes", "Map"}
  end
  if item and (item.kind == "fishing_pole" or item.kind == "lure") then
    return {"Overview", "Vendors", "Drops", "Crafted", "Quest", "Map"}
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
  if item.kind == "item" then
    local vendors, drops, crafts = V.itemVendors(item.id),
      V.itemDrops(item.id), V.itemCrafts(item.id)
    if section == "Overview" then
      add("Item Name", item.name, ns.catalog.icon("item", item.id), item.confidence)
      add("Item ID", item.id, ns.catalog.icon("item", item.id), item.confidence,
        {itemId = item.id})
      add("Vendors", #vendors .. " referenced/observed sellers",
        "Interface\\Icons\\INV_Misc_Bag_10", "mixed_sources")
      add("Drops / fishing pools", #drops .. " observed source relationships",
        "Interface\\Icons\\INV_Misc_Map_01", "observed")
      add("Created by", #crafts .. " observed/client recipes",
        "Interface\\Icons\\INV_Misc_Food_15", "mixed_sources")
    elseif section == "Vendors" then
      for _, vendor in ipairs(vendors) do
        add(vendor.name, vendor.confidence .. (vendor.installs and
          (" | " .. vendor.installs .. " installs") or ""),
          "Interface\\Icons\\INV_Misc_Bag_10", vendor.confidence,
          {vendorId = vendor.id})
      end
    elseif section == "Drops" then
      for _, drop in ipairs(drops) do
        local label = drop.note or (tostring(drop.installs or 0) ..
          " installs | " .. tostring(drop.reports or 0) .. " loot windows")
        add(drop.title, label,
          drop.kind == "pool" and "Interface\\Icons\\INV_Misc_Fish_02" or
            "Interface\\Icons\\Ability_Hunter_BeastCall", drop.confidence,
          {npcId = drop.npcId, objectId = drop.objectId,
            mapID = drop.mapID, x = drop.x, y = drop.y})
      end
    elseif section == "Crafted" then
      for _, craft in ipairs(crafts) do
        add(craft.title, "Spell " .. craft.spellId .. " | " .. craft.confidence,
          ns.catalog.icon("spell", craft.spellId), craft.confidence,
          {spellId = craft.spellId, recipeId = craft.spellId})
      end
    elseif section == "Map" then
      for _, loc in ipairs(V.itemMapPoints(item.id)) do
        local zone = findZone(loc.mapID)
        add(loc.label, (zone and zone.name or "Map " .. loc.mapID) ..
          string.format(" (%.1f, %.1f)", loc.x * 100, loc.y * 100),
          "Interface\\Icons\\INV_Misc_Map_01", loc.source, loc)
      end
    end
  elseif item.kind == "observed_npc" then
    local npc = source() and source().vendor(item.id) or {}
    if section == "Overview" then
      add("Creature ID", item.id, "Interface\\Icons\\Ability_Hunter_BeastCall",
        item.confidence)
      add("Loot relationships", #(source() and source().dropsByNpc(item.id) or {}) ..
        " fishing-related item sources", "Interface\\Icons\\INV_Misc_Map_01",
        "observed")
      add("Observed positions", #(npc.spots or {}) .. " evidence points",
        "Interface\\Icons\\INV_Misc_Map_01", item.confidence)
    elseif section == "Drops" then
      for _, drop in ipairs(source() and source().dropsByNpc(item.id) or {}) do
        add(ns.catalog.name("item", drop.itemId),
          drop.installs .. " installs | " .. drop.windows .. " loot windows",
          ns.catalog.icon("item", drop.itemId), drop.confidence,
          {itemId = drop.itemId})
      end
    elseif section == "Goods" then
      for id, goods in pairs((ns.data.everloot or {}).vendorItems or {}) do
        for _, offer in ipairs(goods) do
          if offer.npcId == item.id then
            add(ns.catalog.name("item", id), offer.installs .. " independent installs",
              ns.catalog.icon("item", id),
              offer.installs >= 3 and "observed_confirmed" or "observed_provisional",
              {itemId = id})
          end
        end
      end
    elseif section == "Map" then
      for _, loc in ipairs(npc.spots or {}) do
        add(loc.near and "Nearby interaction" or "NPC location",
          string.format("Map %d: %.1f, %.1f", loc.mapID,
            loc.x * 100, loc.y * 100),
          "Interface\\Icons\\INV_Misc_Map_01", "observed",
          {mapID = loc.mapID, x = loc.x, y = loc.y})
      end
    end
  elseif item.kind == "zone" then
    local fish = ns.data.referenceZoneFish and ns.data.referenceZoneFish[item.id] or {}
    local observedFish = {}
    for id, zones in pairs((ns.data.everloot or {}).fishing or {}) do
      for _, observed in ipairs(zones) do
        if observed.mapID == item.id then
          observedFish[#observedFish + 1] = {id = id, installs = observed.installs,
            windows = observed.windows}
        end
      end
    end
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
      add("Observed fish", #observedFish .. " sourced zone catches",
        "Interface\\Icons\\INV_Misc_Fish_02", "observed")
      add("School sightings", #sightings.schools .. " player-recorded positions",
        "Interface\\Icons\\INV_Misc_Spyglass_03", "user_observation")
      add("Vendor references", #vendors .. " mapped NPCs", "Interface\\Icons\\INV_Misc_Bag_10",
        "mixed_source_reference")
    elseif section == "Fish" then
      local observedSet = {}
      for _, rec in ipairs(observedFish) do
        observedSet[rec.id] = true
        add(nameFor(rec.id), rec.installs .. " installs | " ..
          rec.windows .. " loot windows",
          ns.catalog.icon("item", rec.id),
          rec.installs >= 3 and "observed_confirmed" or "observed_provisional",
          {itemId = rec.id})
      end
      for _, rec in ipairs(fish) do
        local id = type(rec) == "table" and rec.id or rec
        local evidence = type(rec) == "table" and rec.evidence or "reference"
        if not observedSet[id] then
          add(nameFor(id), "Item " .. id .. " | " .. evidence,
            ns.catalog.icon("item", id), evidence, {itemId = id})
        end
      end
    elseif section == "Schools" then
      for name, spots in pairs(ns.data.referenceSchoolLocations or {}) do
        for _, spot in ipairs(spots) do
          if spot.mapID == item.id and validPlace(spot) then
            add(name, string.format("Published guide lead %.1f, %.1f",
              spot.x * 100, spot.y * 100), "Interface\\Icons\\INV_Misc_Fish_02",
              "guide_reference", spot)
          end
        end
      end
      for _, observed in ipairs(source() and source().schools() or {}) do
        for _, loc in ipairs(observed.spots or {}) do
          if loc.mapID == item.id then
            add(observed.name, "Object position | " .. loc.installs ..
              " independent installs", "Interface\\Icons\\Trade_Fishing",
              loc.installs >= 3 and "observed_confirmed" or "observed_provisional",
              {mapID = loc.mapID, x = loc.x, y = loc.y})
          end
        end
      end
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
    local sellers, drops = V.itemVendors(item.id), V.itemDrops(item.id)
    if section == "Overview" then
      add("Item Name", item.name, ns.catalog.icon("item", item.id), item.confidence)
      add("Item ID", item.id, ns.catalog.icon("item", item.id), item.confidence)
      add("Fishing-water locations", #places .. " sourced/reference zones",
        "Interface\\Icons\\INV_Misc_Fish_02", "mixed_sources")
      add("Vendor sellers", #sellers .. " recorded/reference candidates",
        "Interface\\Icons\\INV_Misc_Bag_10", "mixed_sources")
      add("Other loot sources", #drops .. " creature/pool/reference relations",
        "Interface\\Icons\\INV_Misc_Map_01", "mixed_sources")
    elseif section == "Zones" or section == "Map" then
      for _, place in ipairs(places) do
        add(place.name, "Map " .. place.mapID .. " | " .. place.evidence,
          "Interface\\Icons\\INV_Misc_Map_01", place.evidence,
          {mapID = place.mapID})
      end
    elseif section == "Sources" then
      for _, seller in ipairs(sellers) do
        add(seller.name, "Vendor | " .. tostring(seller.confidence),
          "Interface\\Icons\\INV_Misc_Bag_10", seller.confidence,
          {vendorId = seller.id})
      end
      for _, drop in ipairs(drops) do
        add(drop.title, "Loot | " .. tostring(drop.confidence),
          "Interface\\Icons\\Ability_Hunter_BeastCall", drop.confidence,
          {npcId = drop.npcId, objectId = drop.objectId,
            mapID = drop.mapID, x = drop.x, y = drop.y})
      end
      if #sellers == 0 and #drops == 0 then
        add("Other sources unknown", "No observed vendor or creature source yet",
          "Interface\\Icons\\INV_Misc_QuestionMark", "unknown")
      end
    elseif section == "Recipes" then
      for _, r in ipairs(ns.catalog.recipeList()) do
        for _, ing in ipairs(r.ingredients or {}) do
          if ing.itemId == item.id then
            add(ns.catalog.name("spell", r.spellId),
              ing.amount .. " x ingredient | Spell " .. r.spellId,
              r.outputItemId and ns.catalog.icon("item", r.outputItemId),
              "game_files_unconfirmed", {recipeId = r.spellId})
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
    local observations = source() and source().schoolLocations(item.name) or {}
    if section == "Overview" then
      add("School type", item.name, B.icon(item), item.confidence)
      add("Your sightings", #places .. " nearby player positions",
        "Interface\\Icons\\INV_Misc_Spyglass_03", "user_observation")
      add("Observed object locations", #observations .. " sourced object sightings",
        "Interface\\Icons\\INV_Misc_Map_01", "observed")
      local guides = (ns.data.referenceSchoolLocations or {})[item.name] or {}
      add("Guide reference places", #guides .. " historical map leads",
        "Interface\\Icons\\INV_Misc_Map_01", "guide_reference")
      local seen = {}
      for _, place in ipairs(places) do seen[place.mapID] = true end
      for _, place in ipairs(observations) do seen[place.mapID] = true end
      for _, place in ipairs(guides) do seen[place.mapID] = true end
      local zoneNames = {}
      for mapID in pairs(seen) do
        local zone = findZone(mapID)
        zoneNames[#zoneNames + 1] = zone and zone.name or ("Map " .. mapID)
      end
      table.sort(zoneNames)
      add("Recorded areas", #zoneNames > 0 and table.concat(zoneNames, ", ")
        or "No observed areas yet", "Interface\\Icons\\INV_Misc_Map_01",
        "mixed_observation")
    else
      for _, place in ipairs(observations) do
        local zone = findZone(place.mapID)
        add(zone and zone.name or ("Map " .. place.mapID),
          string.format("School object: %.1f, %.1f", place.x * 100, place.y * 100),
          "Interface\\Icons\\Trade_Fishing", place.source,
          {mapID = place.mapID, x = place.x, y = place.y})
      end
      for _, place in ipairs((ns.data.referenceSchoolLocations or {})[item.name] or {}) do
        local zone = findZone(place.mapID)
        add(zone and zone.name or ("Map " .. place.mapID),
          string.format("Guide lead: %.1f, %.1f | not active pool",
            place.x * 100, place.y * 100), B.icon(item),
          "guide_reference", place)
      end
      for _, place in ipairs(places) do
        local zone = findZone(place.mapID)
        add(zone and zone.name or ("Map " .. place.mapID),
          string.format("Nearby observation: %.1f, %.1f",
          place.x * 100, place.y * 100), "Interface\\Icons\\INV_Misc_Map_01",
          "user_observation", {mapID = place.mapID, x = place.x, y = place.y})
      end
    end
  elseif item.kind == "fishing_pole" or item.kind == "lure" then
    local vendors, drops, crafts, quests = V.itemVendors(item.id),
      V.itemDrops(item.id), V.itemCrafts(item.id), V.itemQuests(item.id)
    if section == "Overview" then
      add("Item Name", item.name, ns.catalog.icon("item", item.id), item.confidence)
      add("Item ID", item.id, ns.catalog.icon("item", item.id), item.confidence)
      add("Equipment", item.kind == "lure" and "Fishing lure" or "Fishing pole",
        ns.catalog.icon("item", item.id), item.confidence)
      add("Potential vendors", #vendors .. " observed/reference sellers",
        "Interface\\Icons\\INV_Misc_Bag_10", "mixed_sources")
      add("Loot/objects", #drops .. " observed/historical sources",
        "Interface\\Icons\\INV_Misc_Map_01", "mixed_sources")
      add("Created by", #crafts .. " observed/client/guide recipes",
        "Interface\\Icons\\Trade_Engineering", "mixed_sources")
      add("Quest rewards", #quests .. " historical quest sources",
        "Interface\\Icons\\INV_Misc_Book_09", "classic_reference")
    elseif section == "Vendors" then
      for _, vendor in ipairs(vendors) do
        add(vendor.name, tostring(vendor.confidence or "unknown"),
          "Interface\\Icons\\INV_Misc_Bag_10", vendor.confidence,
          {vendorId = vendor.id})
      end
    elseif section == "Drops" then
      for _, drop in ipairs(drops) do
        add(drop.title, drop.note or (tostring(drop.installs or 0) .. " installs"),
          drop.npcId and "Interface\\Icons\\Ability_Hunter_BeastCall"
            or "Interface\\Icons\\INV_Misc_Map_01",
          drop.confidence, {npcId = drop.npcId, objectId = drop.objectId,
            mapID = drop.mapID, x = drop.x, y = drop.y})
      end
    elseif section == "Crafted" then
      for _, craft in ipairs(crafts) do
        add(craft.title, craft.note or tostring(craft.confidence),
          craft.spellId and ns.catalog.icon("spell", craft.spellId)
            or "Interface\\Icons\\Trade_Engineering", craft.confidence,
          craft.spellId and {recipeId = craft.spellId, spellId = craft.spellId}
            or nil)
      end
    elseif section == "Quest" then
      for _, quest in ipairs(quests) do
        add(quest.title, quest.note or "Historical quest reward",
          "Interface\\Icons\\INV_Misc_Book_09", quest.confidence,
          {mapID = quest.mapID})
      end
    elseif section == "Map" then
      for _, loc in ipairs(V.itemMapPoints(item.id)) do
        local zone = findZone(loc.mapID)
        add(loc.label, (zone and zone.name or "Map " .. loc.mapID) ..
          string.format(" (%.1f, %.1f)", loc.x * 100, loc.y * 100),
          "Interface\\Icons\\INV_Misc_Map_01", loc.source, loc)
      end
      for _, ref in ipairs((ns.data.referenceAcquisition or {})[item.id] or {}) do
        if ref.mapID then
          local zone = findZone(ref.mapID)
          add(ref.title, "Zone: " .. tostring(zone and zone.name or ref.mapID)
            .. " | region only, no exact pin", "Interface\\Icons\\INV_Misc_Map_01",
            ref.confidence, {mapID = ref.mapID})
        end
      end
    end
  elseif item.kind == "Cooking" or item.kind == "Fishing"
      or item.kind == "gamefile_recipe" then
    local plan = ns.kitchen.catalogPlan(item.id, 1)
    if section == "Overview" then
      local status, statusSource = "unknown", "not_yet_scanned"
      if ns.recipeKnowledge then status, statusSource = ns.recipeKnowledge.status(item.id) end
      local known = status == "known"
      local clientVerified = known and (statusSource == "client_spellbook"
        or statusSource == "client_recipe_info"
        or statusSource == "profession_scan")
      local detail = known and "Known" or "Unknown"
      if clientVerified then
        detail = detail .. " | confirmed by client"
      elseif statusSource == "not_yet_scanned" then
        detail = detail .. " (unverified) | click: Known"
      else
        detail = detail .. (known and " | click: Unknown" or " | click: Known")
      end
      add("Recipe knowledge", detail,
        "Interface\\Icons\\INV_Misc_Book_09", statusSource,
        {recipeId = item.id, toggleRecipe = true, recipeReadOnly = clientVerified})
    end
    if section == "Sources" then
      local recipe = ns.catalog.recipe(item.id) or
        ((ns.data.gameFiles or {}).recipes or {})[item.id]
      local found = 0
      for _, trainer in ipairs(source() and source().trainersForRecipe(item.id) or {}) do
        found = found + 1
        add(trainer.title, "Trainer | " .. trainer.installs .. " independent installs",
          "Interface\\Icons\\INV_Misc_Bag_10", trainer.confidence,
          {vendorId = trainer.npcId})
      end
      if recipe and recipe.recipeItemId then
        local scroll = recipe.recipeItemId
        for _, seller in ipairs(V.itemVendors(scroll)) do
          found = found + 1
          add(seller.name, "Sells recipe item " .. scroll,
            "Interface\\Icons\\INV_Misc_Bag_10", seller.confidence,
            {vendorId = seller.id})
        end
        for _, drop in ipairs(V.itemDrops(scroll)) do
          found = found + 1
          add(drop.title, "Recipe item " .. scroll .. " | " .. drop.confidence,
            "Interface\\Icons\\INV_Misc_Map_01", drop.confidence,
            {npcId = drop.npcId, objectId = drop.objectId,
            mapID = drop.mapID, x = drop.x, y = drop.y})
        end
      end
      if found == 0 then
        add("Acquisition unknown", "No Forever-observed trainer, vendor or drop evidence",
          "Interface\\Icons\\INV_Misc_Book_09", "unknown")
      end
    elseif plan then
      add("Cooking skill", plan.minimumSkill or "Unknown",
        "Interface\\Icons\\INV_Misc_Food_15", "verified_client")
      local recipe = ns.catalog.recipe(item.id)
      add("Produces", plan.output,
        recipe and recipe.outputItemId and ns.catalog.icon("item", recipe.outputItemId),
        "verified_client", recipe and recipe.outputItemId
          and {itemId = recipe.outputItemId} or nil)
      if section == "Overview" then
        add("Acquisition", "Select Sources for trainer, vendor and drop records",
          "Interface\\Icons\\INV_Misc_Book_09", "mixed_sources")
      end
      for _, ing in ipairs(plan.reagents or {}) do
        add(ing.name, (ing.need or 0) .. " needed | " .. (ing.missing or 0) .. " missing",
          ns.catalog.icon("item", ing.itemId), "verified_client", {itemId = ing.itemId})
      end
    elseif item.kind == "gamefile_recipe" then
      local rec = ((ns.data.gameFiles or {}).recipes or {})[item.id]
      if rec then
        add("Profession", rec.profession or "Unknown",
          "Interface\\Icons\\INV_Misc_Book_09", "game_files_unconfirmed")
        add("Minimum skill", rec.minimumSkill or "Unknown",
          "Interface\\Icons\\INV_Misc_Food_15", "game_files_unconfirmed")
        if rec.outputItemId then
          add("Produces", ns.catalog.name("item", rec.outputItemId),
            ns.catalog.icon("item", rec.outputItemId), "game_files_unconfirmed",
            {itemId = rec.outputItemId})
        end
        for _, ing in ipairs(rec.reagents or {}) do
          if ing.itemId then
            add(ns.catalog.name("item", ing.itemId), ing.count .. " needed",
              ns.catalog.icon("item", ing.itemId), "game_files_unconfirmed",
              {itemId = ing.itemId})
          end
        end
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
