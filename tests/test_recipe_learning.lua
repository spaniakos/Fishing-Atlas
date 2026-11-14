-- SPDX-License-Identifier: GPL-3.0-or-later
-- Cooking spell vs teaching-scroll distinction. Do not call yellow=290
-- a learn requirement when client build exports incorrect minimumSkill=1.
local ns = {data = {gameFiles = {recipes = {
  [18243] = {profession = "Cooking", minimumSkill = 1,
    yellow = 290, grey = 330, outputItemId = 13931},
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
print("Cooking spell learning rank and trainer/scroll source tests passed")
