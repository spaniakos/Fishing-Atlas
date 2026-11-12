-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
local function chunk(path)
  local f = assert(loadfile(path))
  return function(...) return f(...) end
end
chunk("FishingAtlas/Core/Namespace.lua")("FishingAtlas", ns)
chunk("FishingAtlas/Core/Storage.lua")("FishingAtlas", ns)
FishingAtlasDB = nil
time = function() return 1700000000 end
assert(ns.storage.init())
assert(ns.storage.count() == 0)
assert(ns.util.gridKey(1, 0.5, 0.25) == "1:5000:2500")
assert(not ns.util.gridKey(1, -0.2, 0.3))
local node, fresh = ns.storage.add(1434, 0.426, 0.183, "Test school", "manual")
assert(node and fresh and ns.storage.count() == 1)
assert(node.precision == "player_position")
local again, fresh2 = ns.storage.add(1434, 0.427, 0.184, "Test school", "manual")
assert(again == node and not fresh2 and again.sightings == 2)
assert(#ns.storage.inZone(1434) == 1)
assert(#ns.storage.inZone(12) == 0)
assert(not ns.storage.add(1, 2, 0.5, "invalid"))
assert(ns.storage.latest() == node)
assert(ns.util.safeText("x|y") == "x y")
assert(ns.storage.count() == 1)
FishingAtlasDB = { schemaVersion = 999, observations = {} }
local old, err = ns.storage.init()
assert(old == nil and err)
print("storage tests passed")
