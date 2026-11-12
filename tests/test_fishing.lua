-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Fishing/Mode.lua"))("FishingAtlas", ns)
local enabled, message = ns.fishing.setEnabled(true)
assert(not enabled and message)
local cleared, clearMsg = ns.fishing.setEnabled(false)
assert(cleared and clearMsg)
local calls, button = 0
UIParent = {}
CreateFrame = function() return {SetAttribute = function() calls = calls + 1 end} end
SetOverrideBindingClick = function() calls = calls + 1 end
ClearOverrideBindings = function() calls = calls + 1 end
InCombatLockdown = function() return false end
assert(ns.fishing.setEnabled(true))
assert(ns.fishing.isEnabled())
assert(calls == 3)
assert(ns.fishing.setEnabled(false))
assert(not ns.fishing.isEnabled())
InCombatLockdown = function() return true end
assert(not ns.fishing.setEnabled(true))
print("fishing mode tests passed")
