-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
local function load(path) return assert(loadfile(path))("FishingAtlas", ns) end
load("FishingAtlas/Core/Namespace.lua")
load("FishingAtlas/Core/Storage.lua")
load("FishingAtlas/Atlas/Schools.lua")
FishingAtlasDB = {schemaVersion = 1, observations = {{mapID = 1411, x = 0.1, y = 0.2}}}
time = function() return 1700000100 end
assert(ns.storage.init())
assert(ns.storage.db.schemaVersion == 2)
assert(ns.storage.count() == 1)
assert(ns.schools.total() == 0)
assert(not ns.schools.record(1411, -1, 0.3, "Test"))
assert(not ns.schools.record(1411, 0.5, 0.3, ""))
local first, created = ns.schools.record(1411, 0.5, 0.3, "Floating Wreckage")
assert(first and created)
assert(first.precision == "player_position_near_school")
assert(first.verifiedSpawn == false)
local again, fresh = ns.schools.record(1411, 0.501, 0.3, "Floating Wreckage")
assert(not fresh and again == first and first.sightings == 2)
assert(ns.schools.total() == 1 and ns.storage.count() == 1)
assert(#ns.schools.inZone(1411) == 1 and #ns.schools.inZone(1412) == 0)
print("school candidate tests passed")
