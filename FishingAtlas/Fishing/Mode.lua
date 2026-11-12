-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.fishing = {}
local M = ns.fishing
local button
local enabled = false
function M.isEnabled() return enabled end
function M.setEnabled(want)
  if type(InCombatLockdown) == "function" and InCombatLockdown() then
    return false, "Cannot change fishing bindings during combat"
  end
  if not want then
    if button and type(ClearOverrideBindings) == "function" then ClearOverrideBindings(button) end
    enabled = false
    return true, "Fishing Space binding disabled; normal binding restored"
  end
  if type(CreateFrame) ~= "function" or type(SetOverrideBindingClick) ~= "function" then
    return false, "Secure casting/binding APIs unavailable in this client"
  end
  if not button then
    button = CreateFrame("Button", "FishingAtlasCastButton", UIParent, "SecureActionButtonTemplate")
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", "Fishing")
  end
  local ok = pcall(SetOverrideBindingClick, button, true, "SPACE", "FishingAtlasCastButton", "LeftButton")
  if not ok then return false, "Unable to install Space binding" end
  enabled = true
  return true, "Space casts Fishing. Use your normal interact control to loot; /fa fishing off restores Space"
end
