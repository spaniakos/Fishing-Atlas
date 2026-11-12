-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Core/Namespace.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Core/Storage.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Atlas/Schools.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Atlas/MapPins.lua"))("FishingAtlas", ns)
FishingAtlasDB = nil
assert(ns.storage.init())
assert(ns.storage.add(1411, 0.1, 0.2, "River"))
assert(ns.schools.record(1411, 0.3, 0.4, "School"))
local points = ns.mapPins.points(1411)
assert(#points == 2)
assert(points[1].kind == "player_position" and not points[1].verifiedSpawn)
assert(points[2].kind == "school_candidate" and not points[2].verifiedSpawn)
assert(#ns.mapPins.points(1412) == 0)
assert(ns.mapPins.refresh() == false)
print("map pin model tests passed")
