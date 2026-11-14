-- SPDX-License-Identifier: GPL-3.0-or-later
-- One physical keypress per cast or bobber interaction. No automated fishing.
local _, ns = ...
ns.fishing = {}
local M = ns.fishing
local button, listener
local enabled, pending = false, false
local fishingSpell = "Fishing"
local currentAction = "off"

local function locked()
  return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function resolveFishingSpell()
  local info
  if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
    local ok, value = pcall(C_Spell.GetSpellInfo, 7620)
    if ok and type(value) == "table" then info = value.name end
  end
  if not info and type(GetSpellInfo) == "function" then
    local ok, value = pcall(GetSpellInfo, 7620)
    if ok and type(value) == "string" then info = value end
  end
  if type(info) == "string" and info ~= "" then return info end
  return "Fishing" -- enUS fallback if the client does not resolve spell ID 7620
end

local function isFishingChannel()
  if type(UnitChannelInfo) ~= "function" then return false end
  local ok, name = pcall(UnitChannelInfo, "player")
  if not ok then return false end
  if type(issecretvalue) == "function" then
    local safe, hidden = pcall(issecretvalue, name)
    if not safe or hidden then return false end
  end
  return type(name) == "string" and name == fishingSpell
end

function M.action() return currentAction end
function M.isEnabled() return enabled end

function M.refresh()
  if not enabled or not button then return false end
  if locked() then pending = true; return false end
  if type(ClearOverrideBindings) ~= "function"
    or type(SetOverrideBindingClick) ~= "function"
    or type(SetOverrideBinding) ~= "function" then return false end
  local interact = isFishingChannel()
  local ok = pcall(function()
    ClearOverrideBindings(button)
    if interact then
      -- Blizzard's built-in soft-target interaction. Cannot force a bite or
      -- select a distant bobber; player still presses Space after the splash.
      SetOverrideBinding(button, true, "SPACE", "INTERACTTARGET")
    else
      SetOverrideBindingClick(button, true, "SPACE", "FishingAtlasCastButton", "LeftButton")
    end
  end)
  if ok then
    currentAction = interact and "interact" or "cast"
    pending = false
  end
  return ok
end

local function ensureFrames()
  if button then return true end
  if type(CreateFrame) ~= "function" or not UIParent then return false end
  local ok, secure = pcall(CreateFrame, "Button", "FishingAtlasCastButton",
    UIParent, "SecureActionButtonTemplate")
  if not ok or not secure or type(secure.SetAttribute) ~= "function" then return false end
  secure:SetAttribute("type", "spell")
  secure:SetAttribute("spell", fishingSpell)
  button = secure
  listener = CreateFrame("Frame")
  if listener and type(listener.SetScript) == "function" then
    listener:SetScript("OnEvent", function(_, event, unit)
      if event == "PLAYER_REGEN_ENABLED" then
        if enabled and pending then M.refresh() end
      elseif unit == "player" and enabled then
        M.refresh()
      end
    end)
    if type(listener.RegisterEvent) == "function" then
      for _, event in ipairs({"UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_INTERRUPTED",
        "UNIT_SPELLCAST_CHANNEL_FAILED", "PLAYER_REGEN_ENABLED"}) do
        pcall(listener.RegisterEvent, listener, event)
      end
    end
  end
  return true
end

function M.setEnabled(want)
  if locked() then return false, "Cannot change fishing bindings during combat" end
  if not want then
    if button and type(ClearOverrideBindings) == "function" then
      pcall(ClearOverrideBindings, button)
    end
    enabled, pending, currentAction = false, false, "off"
    return true, "Fishing Space binding disabled; normal binding restored"
  end
  if type(SetOverrideBindingClick) ~= "function"
    or type(SetOverrideBinding) ~= "function"
    or type(ClearOverrideBindings) ~= "function" then
    return false, "Secure casting/interaction binding APIs unavailable in this client"
  end
  fishingSpell = resolveFishingSpell()
  if not ensureFrames() then return false, "Unable to create secure Fishing button" end
  button:SetAttribute("spell", fishingSpell)
  enabled = true
  if not M.refresh() then
    enabled = false
    pcall(ClearOverrideBindings, button)
    return false, "Unable to install Space cast/interact binding"
  end
  return true, "Space casts Fishing; when the bobber splashes, press Space again to interact. Enable Interact Key and Auto Loot."
end
