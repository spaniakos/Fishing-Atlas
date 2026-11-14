-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Fishing/Mode.lua"))("FishingAtlas", ns)
local enabled, message = ns.fishing.setEnabled(true)
assert(not enabled and message)
local cleared, clearMsg = ns.fishing.setEnabled(false)
assert(cleared and clearMsg)

local action, eventCallback, channel, combat = "none", nil, nil, false
UIParent = {}
CreateFrame = function()
  return {
    SetAttribute = function() end,
    SetScript = function(_, kind, callback)
      if kind == "OnEvent" then eventCallback = callback end
    end,
    RegisterEvent = function() end
  }
end
SetOverrideBindingClick = function(_, _, key, buttonName, mouse)
  assert(key == "SPACE" and buttonName == "FishingAtlasCastButton"
    and mouse == "LeftButton")
  action = "cast"
end
SetOverrideBinding = function(_, _, key, command)
  assert(key == "SPACE" and command == "INTERACTTARGET")
  action = "interact"
end
ClearOverrideBindings = function() action = "none" end
InCombatLockdown = function() return combat end
GetSpellInfo = function(id) if id == 7620 then return "Fishing" end end
UnitChannelInfo = function() return channel end

assert(ns.fishing.setEnabled(true))
assert(ns.fishing.isEnabled() and action == "cast")
assert(type(eventCallback) == "function")
channel = "Fishing"
eventCallback(nil, "UNIT_SPELLCAST_CHANNEL_START", "player")
assert(action == "interact" and ns.fishing.action() == "interact",
  "The same Space key must switch to Blizzard interaction while fishing")
channel = nil
eventCallback(nil, "UNIT_SPELLCAST_CHANNEL_STOP", "player")
assert(action == "cast" and ns.fishing.action() == "cast")
channel = "Hearthstone"
eventCallback(nil, "UNIT_SPELLCAST_CHANNEL_START", "player")
assert(action == "cast", "Another channel must not be treated as fishing")
channel = "Fishing"
eventCallback(nil, "UNIT_SPELLCAST_CHANNEL_START", "party1")
assert(action == "cast", "Other unit casts must not change our binding")
combat = true
eventCallback(nil, "UNIT_SPELLCAST_CHANNEL_START", "player")
assert(action == "cast", "Never alter protected bindings in combat")
assert(not ns.fishing.setEnabled(false))
combat = false
eventCallback(nil, "PLAYER_REGEN_ENABLED")
assert(action == "interact", "Deferred binding should recover out of combat")
assert(ns.fishing.setEnabled(false))
assert(not ns.fishing.isEnabled() and action == "none", "Space override must be restored")
print("secure manual cast/reel and combat-safe binding tests passed")
