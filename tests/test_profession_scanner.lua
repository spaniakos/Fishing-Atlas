-- SPDX-License-Identifier: GPL-3.0-or-later
-- Forever modern profession APIs: Base/Child info and spell-ID recipes.
local ns = {data = {gameFiles = {recipes = {}}},
  catalog = {recipe = function(id)
    return id == 15935 and {spellId = 15935, profession = "Cooking"}
  end, name = function(_, id) return "Spell #" .. id end,
  recipeList = function() return {} end}}
assert(loadfile("FishingAtlas/Kitchen/ProfessionScanner.lua"))("FishingAtlas", ns)
local S = ns.professionScanner
GetTradeSkillLine = function() return "UNKNOWN" end
C_TradeSkillUI = {
  GetBaseProfessionInfo = function()
    return {professionID = 185, professionName = "Cooking", profession = 5}
  end,
  GetAllRecipeIDs = function() return {15935, 8881, 5000, 2541} end,
  GetRecipeInfo = function(id)
    local names = {[15935] = "Crispy Bat Wing", [8881] = "Unlearned",
      [5000] = "Blacksmith's Recipe", [2541] = "Coyote Steak"}
    return {recipeID = id, name = names[id], learned = id ~= 8881}
  end,
  GetProfessionInfoByRecipeID = function(id)
    return {professionID = id == 5000 and 164 or 185,
      professionName = id == 5000 and "Blacksmithing" or "Cooking"}
  end,
  GetRecipeSchematic = function(id)
    return {outputItemID = id == 15935 and 12224 or 2684}
  end,
  IsDataSourceChanging = function() return false end
}
assert(S.detect() == true, "GetBaseProfessionInfo must beat stale legacy UNKNOWN")
local data = assert(S.readCooking())
assert(data.backend == "Forever modern" and data.inspected == 4)
assert(#data.entries == 2 and data.learned == 2)
assert(data.entries[1].spellId == 15935
  and data.entries[1].outputItemId == 12224)
assert(data.entries[2].spellId == 2541,
  "Profession scan must exclude unlearned and foreign recipes")
C_TradeSkillUI.GetBaseProfessionInfo = function() return nil end
C_TradeSkillUI.GetChildProfessionInfo = function()
  return {professionID = 185, professionName = "Cooking"}
end
assert(S.detect() == true, "Forever ChildProfessionInfo must be supported")
C_TradeSkillUI.GetBaseProfessionInfo = function()
  return {professionID = 164, professionName = "Blacksmithing"}
end
assert(S.detect() == false and not S.readCooking(),
  "Wrong open profession must be rejected even if cached Cooking recipes exist")
C_TradeSkillUI.GetBaseProfessionInfo = function()
  return {professionID = 185, professionName = "Cooking"}
end
C_TradeSkillUI.IsDataSourceChanging = function() return true end
assert(not S.readCooking(), "Changing data source must not import stale recipes")
C_TradeSkillUI.IsDataSourceChanging = function() return false end
C_TradeSkillUI.GetAllRecipeIDs = function() return {} end
assert(not S.readCooking(), "Empty data must not claim a successful scan")
C_TradeSkillUI.GetAllRecipeIDs = function() return {15935} end
C_TradeSkillUI.GetRecipeInfo = function()
  return {name = "Crispy Bat Wing", learned = false}
end
local unlearned = assert(S.readCooking())
assert(unlearned.inspected == 1 and #unlearned.entries == 0,
  "Fully unlearned list is valid but imports nothing")
C_TradeSkillUI = nil
GetTradeSkillLine = function() return "Cooking" end
GetNumTradeSkills = function() return 2 end
GetTradeSkillInfo = function(i)
  if i == 1 then return "Cooking", "header" end
  return "Crispy Bat Wing", "optimal"
end
GetTradeSkillRecipeLink = function()
  return "|Henchant:15935|h[Crispy Bat Wing]|h"
end
GetTradeSkillItemLink = function()
  return "|Hitem:12224|h[Crispy Bat Wing]|h"
end
local classic = assert(S.readCooking())
assert(classic.backend == "legacy tradeskill" and #classic.entries == 1)
assert(classic.entries[1].spellId == 15935)
print("Forever modern/legacy Cooking identity, filtering and load guards passed")
