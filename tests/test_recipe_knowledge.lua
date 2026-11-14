-- SPDX-License-Identifier: GPL-3.0-or-later
local name = "Fisher"
UnitFullName = function() return name, "Forever" end
local ns = {storage = {db = {}}}
assert(loadfile("FishingAtlas/Kitchen/RecipeKnowledge.lua"))("FishingAtlas", ns)
local K = ns.recipeKnowledge
assert(K.status(18243) == "unchecked")
assert(K.cycle(18243) == "known")
assert(K.status(18243) == "known")
assert(K.cycle(18243) == "unknown")
assert(K.status(18243) == "unknown")
name = "Chef"
assert(K.status(18243) == "unchecked", "Knowledge leaked between characters")
assert(K.set(18243, "known"))
name = "Fisher"
assert(K.status(18243) == "unknown")
assert(K.cycle(18243) == "unchecked")
assert(K.status(18243) == "unchecked")
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
print("per-character recipe tracking and unsupported-event startup tests passed")
