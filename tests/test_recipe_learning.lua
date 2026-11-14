-- SPDX-License-Identifier: GPL-3.0-or-later
-- Cooking spell vs teaching-scroll distinction. Do not call yellow=290
-- a learn requirement when client build exports incorrect minimumSkill=1.
local ns = {data = {gameFiles = {recipes = {
  [18243] = {profession = "Cooking", minimumSkill = 1,
    yellow = 290, grey = 330, outputItemId = 13931},
  [2795] = {profession = "Cooking", minimumSkill = 1,
    yellow = 60, grey = 100, outputItemId = 2888},
  [18247] = {profession = "Cooking", minimumSkill = 1,
    yellow = 315, grey = 355, outputItemId = 13935},
  [7751] = {profession = "Cooking", minimumSkill = 1,
    yellow = 45, grey = 85, outputItemId = 6290},
  [7753] = {profession = "Cooking", minimumSkill = 1,
    yellow = 90, grey = 130, outputItemId = 4592},
  [100001] = {profession = "Cooking", minimumSkill = 1,
    yellow = 175, grey = 230, outputItemId = 5555},
  [100002] = {profession = "Cooking", minimumSkill = 1,
    yellow = 1, grey = 5}
}}}, util = {validCoordinate = function(n)
  return type(n) == "number" and n >= 0 and n <= 1
end}}
ns.catalog = {recipe = function(id)
  if id == 18243 then return {spellId = id, profession = "Cooking",
    cookingSkill = 1, yellowSkill = 290, greySkill = 330,
    recipeItemId = 13945, outputItemId = 13931} end
end}
ns.sources = {
  trainersForRecipe = function(id)
    if id == 100001 then return {{npcId = 42, title = "Cooking Trainer",
      confidence = "observed_provisional"}} end
    return {}
  end,
  vendorLocations = function(id)
    if id == 42 then return {{mapID = 1413, x = 0.3, y = 0.4}} end
    return {}
  end,
  vendorsForItem = function(id)
    if id == 13945 then
      return {{npcId = 42, title = "Cooking Vendor",
        confidence = "observed_provisional"}} end
    return {}
  end,
  dropsForItem = function() return {} end
}
assert(loadfile("FishingAtlas/Data/RecipeLearningReferences.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Kitchen/RecipeLearning.lua"))("FishingAtlas", ns)
local L = ns.recipeLearning
local nightfin = L.info(18243)
assert(nightfin.requiredSkill == 250 and nightfin.yellow == 290
  and nightfin.grey == 330 and nightfin.recipeItemId == 13945)
local unknown = L.info(100001)
assert(unknown.requiredSkill == nil and unknown.yellow == 175,
  "Client minimumSkill=1 with yellow>1 is NOT a reliable learn rank")
assert(L.info(100002).requiredSkill == 1)
local sources = L.sources(18243)
local foundScroll, foundVendor, foundClassic = false, false, false
for _, item in ipairs(sources) do
  if item.kind == "recipe_item" and item.itemId == 13945 then
    foundScroll = true
  elseif item.kind == "vendor" and item.mapID == 1413
      and item.x == 0.3 then foundVendor = true
  elseif item.kind == "historical_vendor" and item.label == "Gikkix"
      and not item.x then foundClassic = true end
end
assert(foundScroll and foundVendor and foundClassic,
  "Cooking spell lists teaching scroll, observed stock and Classic leads separately")
assert(#L.locations(18243) == 1)
local teaches = L.sources(100001)
assert(teaches[1].kind == "trainer" and teaches[1].npcId == 42)
assert(#L.locations(100001) == 1)
assert(#L.sources(100002) == 0)
local ribs = L.info(2795)
assert(ribs.requiredSkill == 25 and ribs.recipeItemId == 2889
  and ribs.yellow == 60 and ribs.grey == 100,
  "Forever Beer Basted Boar Ribs must show Cooking 25 and scroll 2889")
local vendor, quest, item = false, false, false
for _, rec in ipairs(L.sources(2795)) do
  if rec.kind == "vendor" and rec.label == "Kendor Kabonka" and rec.npcId == 340
      and rec.mapID == 1453 and rec.x == 0.775 then vendor = true end
  if rec.kind == "quest" and rec.questId == 384 and rec.mapID == 1426
      and rec.y == 0.524 then quest = true end
  if rec.kind == "recipe_item" and rec.itemId == 2889 then item = true end
end
assert(vendor and quest and item,
  "Cooking ability Sources must contain teaching scroll, seller and quest")
assert(#L.locations(2795) == 2,
  "Reference vendor/quest positions must reach the map pin model")
local salmon = L.info(18247)
assert(salmon.requiredSkill == 275 and salmon.recipeItemId == 13949)
assert(#L.locations(18247) == 2)
assert(L.info(7751).recipeItemId == 6325)
assert(L.info(7753).requiredSkill == 50 and L.info(7753).recipeItemId == 6328)
print("Cooking spell requirements, teaching items and sourced acquisition paths passed")
