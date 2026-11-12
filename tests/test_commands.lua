-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
local load = function(path) return assert(loadfile(path))("FishingAtlas", ns) end
load("FishingAtlas/Core/Namespace.lua")
load("FishingAtlas/Core/Storage.lua")
load("FishingAtlas/Data/Fish.lua")
load("FishingAtlas/Atlas/Schools.lua")
load("FishingAtlas/Core/Commands.lua")
FishingAtlasDB = nil
assert(ns.storage.init())
local logs = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) logs[#logs+1] = m end }
C_Map = {
  GetBestMapForUnit = function() return 1434 end,
  GetPlayerMapPosition = function() return {GetXY = function() return 0.3, 0.7 end} end,
}
ns.commands.run("add My Spot")
assert(ns.storage.count() == 1)
ns.commands.run("add My Spot")
assert(ns.storage.count() == 1)
ns.commands.run("nearby")
ns.commands.run("list")
ns.commands.run("stats")
ns.commands.run("notify off")
assert(not ns.storage.db.settings.notifications)
ns.commands.run("waypoint")
assert(#logs >= 6)
print("command tests passed")
