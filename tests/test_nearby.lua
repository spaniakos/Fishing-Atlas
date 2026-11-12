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
print("nearby tests passed")
