-- SPDX-License-Identifier: GPL-3.0-or-later
-- Read-only source graph for sourced, offline Forever observations.
-- The CC BY-SA 4.0 observed dataset is stored in EverlootObserved.lua, separately licensed.
local _, ns = ...
ns.sources = {}
local S = ns.sources
local O = ns.data.everloot or {}
local function tableOrEmpty(v) return type(v) == "table" and v or {} end
local function isPositive(n) return type(n) == "number" and n > 0 end
local function support(n) return (tonumber(n) or 0) >= 3 and "observed_confirmed" or "observed_provisional" end
function S.metadata() return O.meta or {} end
function S.credit()
  return (O.meta and O.meta.credit) or "Data from Everloot (https://everloot.app), CC BY-SA 4.0."
end
function S.itemName(id)
  local rec = tableOrEmpty(O.itemNames)[tonumber(id)]
  return type(rec) == "table" and rec.name or nil
end
function S.npcName(id)
  id = tonumber(id)
  local npc = tableOrEmpty(O.npcs)[id]
  if npc and type(npc.name) == "string" and npc.name ~= "" then return npc.name end
  for _, ref in ipairs(ns.data.referenceVendors or {}) do
    if ref.id == id and type(ref.name) == "string" then return ref.name end
  end
  local observed = ns.storage and ns.storage.db
    and ns.storage.db.recordedNpcNames or {}
  if type(observed[id]) == "string" and observed[id] ~= "" then return observed[id] end
  return "Unidentified creature (NPC " .. tostring(id or "?") .. ")"
end

function S.dropsByNpc(npcId)
  npcId = tonumber(npcId)
  local results = {}
  for itemId, sources in pairs(tableOrEmpty(O.drops)) do
    if not ns.fishingScope or ns.fishingScope.item(itemId) then
      for _, rec in ipairs(tableOrEmpty(sources)) do
        if rec.npcId == npcId then
          results[#results + 1] = {itemId = itemId, installs = rec.installs or 0,
            windows = rec.windows or 0, confidence = support(rec.installs)}
        end
      end
    end
  end
  table.sort(results, function(a, b) return a.itemId < b.itemId end)
  return results
end
function S.vendor(id) return tableOrEmpty(O.npcs)[tonumber(id)] end
function S.vendorLocations(id)
  local npc = S.vendor(id)
  return npc and tableOrEmpty(npc.spots) or {}
end
function S.vendorsForItem(id)
  local found = {}
  for _, rec in ipairs(tableOrEmpty(tableOrEmpty(O.vendorItems)[tonumber(id)])) do
    if isPositive(rec.npcId) then
      found[#found + 1] = {kind = "vendor", npcId = rec.npcId,
        title = S.npcName(rec.npcId), installs = rec.installs or 0,
        reports = rec.reports or 0, confidence = support(rec.installs),
        url = "https://everloot.app/database/npcs/" .. rec.npcId}
    end
  end
  return found
end
function S.dropsForItem(id)
  local found = {}
  for _, rec in ipairs(tableOrEmpty(tableOrEmpty(O.drops)[tonumber(id)])) do
    if isPositive(rec.npcId) then
      found[#found + 1] = {kind = "drop", npcId = rec.npcId,
        title = S.npcName(rec.npcId), installs = rec.installs or 0,
        reports = rec.windows or 0, confidence = support(rec.installs)}
    end
  end
  for _, rec in ipairs(tableOrEmpty(tableOrEmpty(O.poolItems)[tonumber(id)])) do
    found[#found + 1] = {kind = "pool", objectId = rec.objectId,
      title = rec.name or ("Object " .. tostring(rec.objectId)),
      installs = rec.installs or 0, reports = rec.windows or 0,
      confidence = support(rec.installs), mapID = rec.mapID,
      x = rec.x, y = rec.y}
  end
  return found
end
function S.fishingForItem(id)
  local found = {}
  for _, rec in ipairs(tableOrEmpty(tableOrEmpty(O.fishing)[tonumber(id)])) do
    if rec.mapID then
      found[#found + 1] = {mapID = rec.mapID, installs = rec.installs or 0,
        reports = rec.windows or 0, confidence = support(rec.installs)}
    end
  end
  return found
end
function S.craftedItem(id)
  local out = {}
  for spellId, rec in pairs(tableOrEmpty(O.recipes)) do
    if rec.productItemId == tonumber(id) then
      out[#out + 1] = {kind = "craft", spellId = spellId,
        title = rec.name or ("Spell " .. spellId), installs = rec.installs or 0,
        confidence = support(rec.installs)}
    end
  end
  table.sort(out, function(a, b) return a.spellId < b.spellId end)
  return out
end
function S.trainersForRecipe(spellId)
  local out = {}
  for _, rec in ipairs(tableOrEmpty(tableOrEmpty(O.trainers)[tonumber(spellId)])) do
    if isPositive(rec.npcId) then
      local npc = S.vendor(rec.npcId) or {}
      out[#out + 1] = {kind = "trainer", npcId = rec.npcId,
        title = npc.name or ("Trainer " .. rec.npcId),
        installs = rec.installs or 0, confidence = support(rec.installs)}
    end
  end
  return out
end
function S.schools()
  return tableOrEmpty(O.schools)
end
function S.schoolLocations(name)
  local out = {}
  for _, school in ipairs(S.schools()) do
    if school.name == name then
      for _, loc in ipairs(tableOrEmpty(school.spots)) do
        if isPositive(loc.mapID) and ns.util.validCoordinate(loc.x)
            and ns.util.validCoordinate(loc.y) then
          out[#out + 1] = {mapID = loc.mapID, x = loc.x, y = loc.y,
            kind = "school", label = name, exact = true,
            source = support(loc.installs), installs = loc.installs or 0}
        end
      end
    end
  end
  return out
end
local function provenanceUrl(entries)
  for _, entry in ipairs(type(entries) == "table" and entries or {}) do
    if entry.verifiedInForever and type(entry.url) == "string" then return entry.url end
  end
  for _, entry in ipairs(type(entries) == "table" and entries or {}) do
    if entry.source == "wow_forever_client_recipe_extract"
        and type(entry.url) == "string" then return entry.url end
  end
  for _, entry in ipairs(type(entries) == "table" and entries or {}) do
    if type(entry.url) == "string" then return entry.url end
  end
  return nil
end

function S.linkFor(item)
  if not item then return nil end
  if item.kind == "school_type" then
    local refs = (ns.data.referenceSchoolLocations or {})[item.name] or {}
    if refs[1] and refs[1].url then return refs[1].url end
    return nil
  end
  if item.kind == "item" or item.kind == "fish" or item.kind == "fishing_pole"
      or item.kind == "lure" then
    local id = tonumber(item.id)
    if tableOrEmpty(O.itemNames)[id] or tableOrEmpty(O.vendorItems)[id]
        or tableOrEmpty(O.drops)[id] or tableOrEmpty(O.fishing)[id] then
      return "https://everloot.app/database/items/" .. tostring(id)
    end
    local entity = ns.catalog.entity("item", id)
    return entity and provenanceUrl(entity.provenance) or nil
  end
  if item.kind == "vendor_reference" then
    if tableOrEmpty(O.npcs)[tonumber(item.id)] then
      return "https://everloot.app/database/npcs/" .. tostring(item.id)
    end
    return "https://github.com/WoW-Forever-Addons/finddon"
  end
  if item.kind == "merchant_observation" or item.kind == "observed_npc" then
    return "https://everloot.app/database/npcs/" .. tostring(item.id)
  end
  if item.kind == "Cooking" or item.kind == "Fishing" then
    local recipe = ns.catalog.recipe(item.id)
    return recipe and provenanceUrl(recipe.provenance) or nil
  end
  if item.kind == "gamefile_recipe" then
    return "https://everloot.app/database/download"
  end
  if item.kind == "zone" then
    local catalog = ns.data.catalog or {}
    local meta = catalog.meta or {}
    return meta.clientMapSource and meta.clientMapSource.source or nil
  end
  return nil
end

function S.creditFor(item)
  if not item then return "Select a record to see its provenance." end
  local kind = item.kind
  if kind == "vendor_reference" then
    return "Finddon / ForeverDB / CMaNGOS mixed reference. Unverified stock."
  end
  if kind == "merchant_observation" then
    return "Observed locally by this game client; merchant stock may change."
  end
  if kind == "observed_npc" then
    return S.credit()
  end
  if kind == "school_type" then
    if #S.schoolLocations(item.name) > 0 then return S.credit() end
    if #(ns.data.referenceSchoolLocations and
        ns.data.referenceSchoolLocations[item.name] or {}) > 0 then
      return "Map leads from wowforever.gg fishing guide; not guaranteed active schools."
    end
    return "Classic school taxonomy; existence on Forever unverified."
  end
  if kind == "gamefile_recipe" then
    return (ns.data.gameFiles and ns.data.gameFiles.meta
      and ns.data.gameFiles.meta.credit)
      or "Blizzard game-file data; unconfirmed."
  end
  if kind == "Cooking" or kind == "Fishing" then
    return "Blizzard game-file recipe metadata; unconfirmed acquisition."
  end
  if kind == "zone" then
    return "Client map data © Blizzard Entertainment, Inc.; fishing sources separate."
  end
  if kind == "item" or kind == "fish" or kind == "fishing_pole" or kind == "lure" then
    local id = tonumber(item.id)
    if tableOrEmpty(O.itemNames)[id] or tableOrEmpty(O.drops)[id]
        or tableOrEmpty(O.vendorItems)[id] or tableOrEmpty(O.fishing)[id] then
      return S.credit()
    end
    return "Client-derived or reference metadata; not Forever-observed evidence."
  end
  return "Locally recorded or mixed reference; inspect the evidence label."
end
