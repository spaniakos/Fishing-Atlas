-- SPDX-License-Identifier: GPL-3.0-or-later
local name = "Fisher"
UnitFullName = function() return name, "Forever" end
local ns = {storage = {db = {}}}
assert(loadfile("FishingAtlas/Kitchen/RecipeKnowledge.lua"))("FishingAtlas", ns)
local K = ns.recipeKnowledge
assert(K.status(18243) == "unknown")
assert(select(2, K.status(18243)) == "not_yet_scanned",
  "Unknown with no profession scan must be identified as unverified")
assert(K.cycle(18243) == "known")
assert(K.status(18243) == "known")
assert(K.cycle(18243) == "unknown")
assert(K.status(18243) == "unknown")
name = "Chef"
assert(K.status(18243) == "unknown", "Knowledge leaked between characters")
assert(K.set(18243, "known"))
name = "Fisher"
assert(K.status(18243) == "unknown")
assert(K.cycle(18243) == "known")
assert(K.status(18243) == "known")
assert(K.cycle(18243) == "unknown")
assert(K.status(18243) == "unknown")
assert(K.set(18243, "unchecked"), "Legacy reset remains for compatibility")
assert(K.status(18243) == "unknown")
-- The real Forever client rejects some retail profession events. This must
-- never interrupt the ADDON_LOADED handler or break slash/minimap startup.
local registered = {}
local eventCallback
CreateFrame = function()
  return {
    RegisterEvent = function(_, event)
      if event == "TRADE_SKILL_UPDATE" or event == "NEW_RECIPE_LEARNED" then
        error("Frame:RegisterEvent(): Attempt to register unknown event " .. event)
      end
      registered[#registered + 1] = event
    end,
    SetScript = function(_, script, callback)
      if script == "OnEvent" then eventCallback = callback end
    end
  }
end
assert(K.start() == true, "Optional event registration should not fail startup")
assert(#K.unsupportedEvents == 2, "Unsupported events should be recorded")
assert(#registered == 4, "Supported events should still register")
assert(type(eventCallback) == "function")
eventCallback()
-- Forever Cooking may expose recipe state by spell ID even before the
-- filtered Trade Skill recipe list is populated.
ns.catalog = {
  recipeList = function() return {{spellId = 4094, outputItemId = 4457}} end,
  name = function(_, id) return id == 4094 and "Barbecued Buzzard Wing" or "Unknown" end,
  recipe = function() return nil end,
}
ns.data = {gameFiles = {recipes = {}}}
C_TradeSkillUI = {
  GetRecipeInfo = function(id)
    return {name = "Barbecued Buzzard Wing", learned = id == 4094}
  end,
}
name = "Fisher"
assert(K.status(4094) == "known", "Direct client Cooking status should be known")
assert(K.cycle(4094) == "known" and K.status(4094) == "known",
  "Client-verified knowledge must not toggle to unknown")
assert(K.scanCatalog() == 1, "Catalog scan must import known Cooking spell")
assert(K.scanCatalog() == 0, "Repeated scan must be idempotent")
name = "Chef"
assert(K.status(4094) == "known", "Direct learned status follows the live client")
print("per-character recipes, Cooking direct scan and safe startup tests passed")
