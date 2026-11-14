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
    if ns.recipeKnowledge then ns.recipeKnowledge.start() end
    ns.nearby.start()
    ns.loot.start()
    ns.vendors.start()
    ns.mapPins.start()
    ns.options.start()
    ns.minimap.start()
  end
end)
