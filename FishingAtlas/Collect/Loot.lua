-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.loot = {}
local L = ns.loot
local slots = {}
local fishing = false
local function reset()
  slots = {}
  fishing = false
end
function L.open()
  reset()
  if type(IsFishingLoot) ~= "function" or not IsFishingLoot() then return end
  if type(GetNumLootItems) ~= "function" or type(GetLootSlotInfo) ~= "function" then return end
  fishing = true
  for slot = 1, GetNumLootItems() do
    local _, name, quantity = GetLootSlotInfo(slot)
    local link = type(GetLootSlotLink) == "function" and GetLootSlotLink(slot) or nil
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
    if type(name) == "string" and type(quantity) == "number" and quantity >= 1 then
      slots[slot] = {id = id, name = name, quantity = quantity}
    end
  end
end
function L.cleared(slot)
  if not fishing then return end
  local entry = slots[slot]
  slots[slot] = nil
  if entry then ns.journal.record(entry.id, entry.name, entry.quantity, "fishing_loot") end
end
function L.start()
  if not CreateFrame then return end
  if L.frame then return end
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("LOOT_OPENED")
  frame:RegisterEvent("LOOT_SLOT_CLEARED")
  frame:RegisterEvent("LOOT_CLOSED")
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_OPENED" then L.open()
    elseif event == "LOOT_SLOT_CLEARED" then L.cleared(...)
    elseif event == "LOOT_CLOSED" then reset() end
  end)
  L.frame = frame
end
