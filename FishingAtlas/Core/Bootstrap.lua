-- SPDX-License-Identifier: GPL-3.0-or-later
local addonName, ns = ...
if not CreateFrame then return end
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" and arg == addonName then
    local _, err = ns.storage.init()
    if err then
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Fishing Atlas: " .. err) end
      return
    end
    SLASH_FISHINGATLAS1 = "/fa"
    SLASH_FISHINGATLAS2 = "/fishingatlas"
    SlashCmdList["FISHINGATLAS"] = ns.commands.run
    -- Optional helpers must never abort the addon-load sequence. Report
    -- their failure but continue registering the minimap and /fa commands.
    local function startOptional(label, callback)
      if type(callback) ~= "function" then return end
      local ok, failure = pcall(callback)
      if not ok and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("Fishing Atlas: " .. label ..
          " disabled on this client: " .. tostring(failure))
      end
    end
    startOptional("Recipe knowledge", ns.recipeKnowledge and ns.recipeKnowledge.start)
    startOptional("Live school detector", ns.liveSchools and ns.liveSchools.start)
    ns.nearby.start()
    ns.loot.start()
    ns.vendors.start()
    ns.mapPins.start()
    ns.options.start()
    ns.minimap.start()
  end
end)
