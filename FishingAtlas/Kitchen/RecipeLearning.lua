-- SPDX-License-Identifier: GPL-3.0-or-later
-- Cooking ABILITY requirements and learning sources, not item scroll metadata.
-- The build-70888 client recipe export has minimumSkill=1 for many high-tier
-- recipes (e.g. Nightfin Soup), so it is not a trustworthy learn requirement.
local _, ns = ...
ns.recipeLearning = {}
local L = ns.recipeLearning

-- Source: existing Data/Recipes.lua Classic references and Forever spell
-- https://www.wowhead.com/forever/spell=18243/nightfin-soup
-- https://www.foreverdb.app/en/forever/spells/18243/nightfin-soup
-- Never expand this list by guessing skill from yellow/grey thresholds.
local historical = {
  [7751] = {minimumSkill = 1, source = "classic_reference"},
  [7753] = {minimumSkill = 50, source = "classic_reference"},
  [18243] = {minimumSkill = 250, source = "forever_public_reference",
    historicalSeller = "Gikkix", historicalZone = "Tanaris",
    historicalMapID = 1446}
}

local function recipe(id)
  id = tonumber(id)
  return ns.catalog and ns.catalog.recipe and ns.catalog.recipe(id)
    or ((ns.data.gameFiles or {}).recipes or {})[id]
end

local function normalized(value)
  if type(value) ~= "string" or value:find("^Unresolved ")
      or value:find("^Spell #") or value:find("^Item #") then return nil end
  local key = value:lower():gsub("^recipe:%s*", "")
    :gsub("[^%w]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return key ~= "" and key or nil
end

local function observed(spellId, rec)
  local data = ns.data.foreverObservedCooking or {}
  local sellers, trainers = nil, (data.trainers or {})[tostring(spellId)] or {}
  local names, seen = {}, {}
  local function try(kind, id)
    if not id or not ns.catalog or type(ns.catalog.name) ~= "function" then return end
    local ok, value = pcall(ns.catalog.name, kind, id)
    local key = ok and normalized(value) or nil
    if key and not seen[key] then
      names[#names + 1] = key
      seen[key] = true
    end
  end
  try("spell", spellId)
  try("item", rec.outputItemId)
  for _, name in ipairs(names) do
    if (data.vendors or {})[name] then
      sellers = data.vendors[name]
      break
    end
  end
  return sellers or {}, trainers
end

local function professionDB(spellId)
  local provider = ns.professionProvider
  if not provider then return nil end
  local skill, source = provider.requirement(spellId)
  local item = provider.teachingItem(spellId)
  return skill, item, source == "borrowed_classic_reference"
end

local function itemTooltipSkill(itemID)
  if not itemID or type(C_TooltipInfo) ~= "table"
      or type(C_TooltipInfo.GetItemByID) ~= "function" then return nil end
  local ok, tooltip = pcall(C_TooltipInfo.GetItemByID, itemID)
  if not ok or type(tooltip) ~= "table" then return nil end
  for _, line in ipairs(tooltip.lines or {}) do
    if type(line.leftText) == "string" then
      local rank = line.leftText:match("Requires%s+Cooking%s*%((%d+)%)")
        or line.leftText:match("Requires%s+Cooking%s+(%d+)")
      if rank and tonumber(rank) and tonumber(rank) > 0 then
        return tonumber(rank)
      end
    end
  end
end

function L.info(spellId)
  local rec = recipe(spellId)
  if not rec and ns.recipeDiscovery then
    local discovery = ns.recipeDiscovery.get(spellId)
    if discovery then
      rec = {profession = "Cooking", outputItemId = discovery.outputItemId}
    end
  end
  if not rec then return nil end
  local min = tonumber(rec.cookingSkill or rec.minimumSkill)
  local yellow = tonumber(rec.yellowSkill or rec.yellow)
  local grey = tonumber(rec.greySkill or rec.grey)
  local ref = (ns.data.recipeLearningReferences or {})[tonumber(spellId)]
    or historical[tonumber(spellId)]
  local sellers, trainers = observed(tonumber(spellId), rec)
  local scroll = tonumber(rec.recipeItemId or (ref and ref.recipeItemId))
  if not scroll then
    local candidate, ambiguous
    for _, seller in ipairs(sellers) do
      if candidate and candidate ~= seller.itemId then ambiguous = true; break end
      candidate = seller.itemId
    end
    if not ambiguous then scroll = candidate end
  end
  local dbSkill, dbItem, borrowed = professionDB(tonumber(spellId))
  if not scroll then scroll = dbItem end
  local tooltipSkill = itemTooltipSkill(scroll)
  local trainerSkill, conflicting = nil, false
  for _, trainer in ipairs(trainers) do
    if type(trainer.skillRank) == "number" and trainer.skillRank > 0 then
      if trainerSkill and trainerSkill ~= trainer.skillRank then conflicting = true end
      trainerSkill = trainer.skillRank
    end
  end
  if conflicting then trainerSkill = nil end
  local learnedSkill, source
  if min and min > 1 then
    learnedSkill, source = min, "client_learn_requirement"
  elseif ref and tonumber(ref.minimumSkill) then
    learnedSkill, source = tonumber(ref.minimumSkill), ref.source
  elseif tooltipSkill then
    learnedSkill, source = tooltipSkill, "client_recipe_item_tooltip"
  elseif trainerSkill then
    learnedSkill, source = trainerSkill, "forever_observed_trainer"
  elseif dbSkill and dbSkill > 0 then
    learnedSkill = dbSkill
    source = borrowed and "borrowed_classic_reference" or "professiondb_forever"
  elseif min == 1 and yellow and yellow <= 1 then
    learnedSkill, source = 1, "client_skill_floor"
  end
  local scrollName = ref and ref.recipeItemName
  if not scrollName and scroll then
    for _, seller in ipairs(sellers) do
      if seller.itemId == scroll then scrollName = seller.itemName; break end
    end
  end
  return {spellId = tonumber(spellId), profession = rec.profession or "Cooking",
    requiredSkill = learnedSkill, requirementSource = source or "unverified",
    yellow = yellow, grey = grey, recipeItemId = scroll,
    recipeItemName = scrollName, outputItemId = rec.outputItemId,
    observedSellers = sellers, observedTrainers = trainers,
    reference = ref, evidence = rec.confidence or "game_files_unconfirmed"}
end

function L.sources(spellId)
  local info = L.info(spellId)
  if not info then return {} end
  local results = {}
  local sources = ns.sources
  for _, trainer in ipairs(info.observedTrainers or {}) do
    results[#results + 1] = {kind = "trainer", npcId = trainer.npcId,
      label = trainer.name, source = "forever_observed_trainer_" ..
        tostring(trainer.sourceBuild),
      mapID = trainer.mapID, x = trainer.x, y = trainer.y,
      skillRank = trainer.skillRank, sourceBuild = trainer.sourceBuild,
      seenOn = trainer.seenOn, installs = trainer.installs}
  end
  for _, teacher in ipairs(sources and sources.trainersForRecipe(spellId) or {}) do
    local npcId = teacher.npcId
    local locations = sources and sources.vendorLocations(npcId) or {}
    if #locations > 0 then
      for _, loc in ipairs(locations) do
        if type(loc.mapID) == "number" and ns.util.validCoordinate(loc.x)
            and ns.util.validCoordinate(loc.y) then
          results[#results + 1] = {kind = "trainer", npcId = npcId,
            label = teacher.title, source = teacher.confidence,
            mapID = loc.mapID, x = loc.x, y = loc.y}
        end
      end
    else
      results[#results + 1] = {kind = "trainer", npcId = npcId,
        label = teacher.title, source = teacher.confidence}
    end
  end
  if info.recipeItemId then
    results[#results + 1] = {kind = "recipe_item",
      itemId = info.recipeItemId, label = "Learn by using recipe item",
      source = info.evidence}
    for _, seller in ipairs(info.observedSellers or {}) do
      if seller.itemId == info.recipeItemId then
        results[#results + 1] = {kind = "vendor", npcId = seller.npcId,
          label = seller.name, source = "forever_observed_vendor_" ..
            tostring(seller.sourceBuild),
          mapID = seller.mapID, x = seller.x, y = seller.y,
          itemId = seller.itemId, sourceBuild = seller.sourceBuild,
          seenOn = seller.seenOn, installs = seller.installs}
      end
    end
    for _, seller in ipairs(sources and sources.vendorsForItem(info.recipeItemId) or {}) do
      local locations = sources and sources.vendorLocations(seller.npcId) or {}
      if #locations == 0 then
        results[#results + 1] = {kind = "vendor", npcId = seller.npcId,
          label = seller.title, source = seller.confidence,
          itemId = info.recipeItemId}
      end
      for _, loc in ipairs(locations) do
        if type(loc.mapID) == "number" and ns.util.validCoordinate(loc.x)
            and ns.util.validCoordinate(loc.y) then
          results[#results + 1] = {kind = "vendor", npcId = seller.npcId,
            label = seller.title, source = seller.confidence,
            mapID = loc.mapID, x = loc.x, y = loc.y,
            itemId = info.recipeItemId}
        end
      end
    end
    for _, drop in ipairs(sources and sources.dropsForItem(info.recipeItemId) or {}) do
      results[#results + 1] = {kind = "drop", npcId = drop.npcId,
        objectId = drop.objectId, label = drop.title,
        source = drop.confidence, mapID = drop.mapID, x = drop.x, y = drop.y,
        itemId = info.recipeItemId}
    end
    if info.reference and info.reference.historicalSeller then
      results[#results + 1] = {kind = "historical_vendor",
        label = info.reference.historicalSeller,
        zone = info.reference.historicalZone,
        mapID = info.reference.historicalMapID,
        source = "classic_reference",
        itemId = info.recipeItemId}
    end
  end
  -- Source rows are independent of the teaching-item link, so a quest or
  -- direct-trainer reference never fabricates an item-spell relationship.
  for _, lead in ipairs(info.reference and info.reference.sources or {}) do
    local entry = {}
    for key, value in pairs(lead) do entry[key] = value end
    if info.recipeItemId and not entry.itemId then
      entry.itemId = info.recipeItemId
    end
    results[#results + 1] = entry
  end
  return results
end

function L.locations(spellId)
  local out, seen = {}, {}
  for _, rec in ipairs(L.sources(spellId)) do
    if type(rec.mapID) == "number" and ns.util.validCoordinate(rec.x)
        and ns.util.validCoordinate(rec.y) then
      local key = string.format("%d:%.4f:%.4f:%s",
        rec.mapID, rec.x, rec.y, rec.label or "")
      if not seen[key] then
        out[#out + 1] = {mapID = rec.mapID, x = rec.x, y = rec.y,
          kind = rec.kind == "drop" and "npc" or "vendor",
          label = rec.label, source = rec.source}
        seen[key] = true
      end
    end
  end
  return out
end
