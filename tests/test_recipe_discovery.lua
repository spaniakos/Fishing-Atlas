-- SPDX-License-Identifier: GPL-3.0-or-later
 local ns = {
  storage = {db = {}},
  util = {safeText = function(s) return s end},
  catalog = {recipe = function() return nil end,
    name = function(_, id) return "Spell #" .. tostring(id) end}
}
assert(loadfile("FishingAtlas/Kitchen/ProfessionScanner.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Kitchen/RecipeDiscovery.lua"))("FishingAtlas", ns)
local D = ns.recipeDiscovery
assert(not D.add("not-an-id"))
local added = assert(D.add(15935, "Crispy Bat Wing"))
assert(added.id == 15935 and added.source == "personal_reference")
assert(#D.list() == 1)
assert(D.add("15935") and #D.list() == 1)
assert(D.get(15935).source == "personal_reference")
assert(not D.scan(), "Cannot scan unrelated professions")
GetTradeSkillLine = function() return "Cooking" end
GetNumTradeSkills = function() return 3 end
GetTradeSkillInfo = function(i)
  if i == 1 then return "Cooking", "header" end
  if i == 2 then return "Coyote Steak", "optimal" end
  return "Boiled Clams", "medium"
end
GetTradeSkillRecipeLink = function(i)
  if i == 2 then return "|cffaabbcc|Henchant:2541|h[Coyote Steak]|h|r" end
  if i == 3 then return "|Hspell:6499|h[Boiled Clams]|h" end
end
GetTradeSkillItemLink = function(i)
  if i == 2 then return "|Hitem:2684|h[Coyote Steak]|h" end
end
local auto = {}
ns.recipeKnowledge = {observeLearned = function(id) auto[id] = true end}
local count, status = D.scan()
assert(count == 2 and status:find("Cooking: 2 learned recipes", 1, true))
assert(D.get(2541).source == "client_profession"
  and D.get(2541).outputItemId == 2684)
assert(D.get(6499).name == "Boiled Clams" and auto[6499] == true)
assert(D.get(15935).source == "personal_reference" and not auto[15935],
  "Manual spell references must not be marked learned")
assert(D.scan() == 0, "Repeated scans must not create duplicate recipes")
GetTradeSkillLine = function() return "Alchemy" end
assert(not D.scan() and not D.get(777),
  "Never import arbitrary non-Cooking professions")
GetTradeSkillLine = nil
GetNumTradeSkills = nil
GetTradeSkillInfo = nil
GetTradeSkillRecipeLink = nil
GetTradeSkillItemLink = nil
-- Exact regression: Forever exposes ONLY modern base-profession info;
-- GetTradeSkillLine is unavailable even though Cooking is open.
C_TradeSkillUI = {
  GetBaseProfessionInfo = function()
    return {professionID = 185, professionName = "Cooking", profession = 5}
  end,
  GetAllRecipeIDs = function() return {15935, 900100, 88881} end,
  GetRecipeInfo = function(id)
    return {recipeID = id, learned = id ~= 88881,
      name = id == 15935 and "Crispy Bat Wing"
        or id == 900100 and "New Forever Cooking" or "Not Learned"}
  end,
  GetProfessionInfoByRecipeID = function()
    return {professionID = 185, professionName = "Cooking"}
  end,
}
local newCount, modernMessage = D.scan()
assert(newCount == 1
  and modernMessage:find("Cooking: 2 learned recipes", 1, true),
  "Modern-only Forever Cooking scan must import learned spells")
assert(D.get(900100).source == "client_profession" and auto[900100],
  "New spell must appear as character-learned in saved discoveries")
assert(D.get(15935).source == "client_profession" and auto[15935],
  "Existing manual entry must be upgraded to positively verified Known")
assert(D.scan() == 0, "Repeated modern scans must not duplicate recipes")
C_TradeSkillUI = nil
print("personal, legacy and Forever modern Cooking discoveries passed")
