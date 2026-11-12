-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Core/Namespace.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Core/Storage.lua"))("FishingAtlas", ns)
ns.catalog = {
  entity = function(_, id)
    if id == 6256 then return {category = "fishing_pole"} end
    if id == 6529 then return {category = "lure"} end
  end,
  name = function(_, id) return "Item " .. id end
}
assert(loadfile("FishingAtlas/Fishing/Gear.lua"))("FishingAtlas", ns)
FishingAtlasDB = nil
assert(ns.storage.init())
assert(ns.gear.set("fishing_pole", "6256"))
assert(ns.gear.set("lure", "6529"))
assert(not ns.gear.set("fishing_pole", "6529"))
assert(not ns.gear.set("lure", "0"))
assert(ns.gear.profile().fishing_pole == 6256)
assert(ns.gear.profile().lure == 6529)
print("gear profiles tests passed")
