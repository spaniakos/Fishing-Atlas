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

function L.info(spellId)
  local rec = recipe(spellId)
  if not rec then return nil end
  local min = tonumber(rec.cookingSkill or rec.minimumSkill)
  local yellow = tonumber(rec.yellowSkill or rec.yellow)
  local grey = tonumber(rec.greySkill or rec.grey)
  local ref = (ns.data.recipeLearningReferences or {})[tonumber(spellId)]
    or historical[tonumber(spellId)]
  local learnedSkill, source
  if min and min > 1 then
    learnedSkill, source = min, "client_learn_requirement"
  elseif ref then
    learnedSkill, source = ref.minimumSkill, ref.source
  elseif min == 1 and yellow and yellow <= 1 then
    -- Only a recipe with its yellow threshold at skill 1 is safely tagged
    -- learnable at 1 from this partial export.
    learnedSkill, source = 1, "client_skill_floor"
  end
  local scroll = tonumber(rec.recipeItemId or (ref and ref.recipeItemId))
  return {spellId = tonumber(spellId), profession = rec.profession or "Cooking",
    requiredSkill = learnedSkill, requirementSource = source or "unverified",
    yellow = yellow, grey = grey, recipeItemId = scroll,
    recipeItemName = ref and ref.recipeItemName or nil,
    outputItemId = rec.outputItemId, reference = ref,
    evidence = rec.confidence or "game_files_unconfirmed"}
end

function L.sources(spellId)
  local info = L.info(spellId)
  if not info then return {} end
  local results = {}
  local sources = ns.sources
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
