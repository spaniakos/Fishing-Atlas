-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {commands = {say = function() end}}
assert(loadfile("FishingAtlas/Core/Namespace.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Core/Storage.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Atlas/Nearby.lua"))("FishingAtlas", ns)
FishingAtlasDB = nil
assert(ns.storage.init())
local point = assert(ns.storage.add(1434, 0.4, 0.2, "Test"))
assert(#ns.nearby.find(1434, 0.406, 0.204, 1) == 1)
assert(#ns.nearby.find(1434, 0.9, 0.9, 1) == 0)
assert(#ns.nearby.find(123, 0.4, 0.2, 1) == 0)
assert(#ns.nearby.find(1434, 0.4, 0.2, -1) == 0)
assert(ns.nearby.distanceSquared(0, 0, 0.3, 0.4) > 0.24)
assert(not ns.nearby.distanceSquared(-1, 0, 0.3, 0.4))
assert(ns.nearby.shouldAlert(point.id, 1000))
assert(not ns.nearby.shouldAlert(point.id, 1001))
assert(ns.nearby.shouldAlert(point.id, 1301))
assert(loadfile("FishingAtlas/Atlas/Schools.lua"))("FishingAtlas", ns)
local school = assert(ns.schools.record(1434, 0.4, 0.2, "Firefin Snapper School"))
assert(#ns.nearby.findSchools(1434, 0.405, 0.2, 1) == 1)
assert(#ns.nearby.findSchools(1434, 0.8, 0.8, 1) == 0)
local notices = {}
ns.commands.say = function(message) notices[#notices + 1] = message end
ns.storage.db.settings.notifications = false
ns.storage.db.settings.schoolAlerts = true
C_Map = {
  GetBestMapForUnit = function() return 1434 end,
  GetPlayerMapPosition = function() return {GetXY = function() return 0.4, 0.2 end} end
}
GetTime = function() return 2000 end
ns.nearby.scan()
assert(#notices == 1 and notices[1]:find("historical", 1, true),
  "Opt-in alerts must never claim a saved school is currently spawned")
ns.nearby.scan()
assert(#notices == 1, "Nearby school alert cooldown must suppress duplicates")
ns.storage.db.settings.schoolAlerts = false
ns.nearby.scan()
assert(#notices == 1, "Opting out must disable historical school alerts")
assert(school.id)
print("nearby tests passed")
