-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Core/Namespace.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Core/Storage.lua"))("FishingAtlas", ns)
local bags = {[0] = {6256, 6529, 9999}, [1] = {}}
C_Container = {
  GetContainerNumSlots = function(bag) return #(bags[bag] or {}) end,
  GetContainerItemID = function(bag, slot) return (bags[bag] or {})[slot] end,
}
GetInventoryItemID = function(_, slot) if slot == 16 then return 6256 end end
GetItemInfoInstant = function(id)
  if id == 9999 then return id, "Weapon", "Fishing Pole", "INVTYPE_2HWEAPON",
    123, 2, 20 end
end
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
assert(#ns.gear.available("fishing_pole") == 2, "Inventory should include indexed and client-typed poles")
assert(#ns.gear.available("lure") == 1, "Only carried lures can be selected")
assert(ns.gear.available("fishing_pole")[1].equipped == true)
assert(ns.gear.set("fishing_pole", "6256"))
assert(ns.gear.set("lure", "6529"))
assert(ns.gear.set("fishing_pole", "9999"), "Uncatalogued client fishing-pole subtype is valid")
assert(not ns.gear.set("fishing_pole", "6529"))
assert(not ns.gear.set("lure", "0"))
assert(not ns.gear.set("lure", "6530"), "Cannot select a lure merely because it is in a catalog")
assert(ns.gear.profile().fishing_pole == 9999)
assert(ns.gear.profile().lure == 6529)
bags[0] = {}
assert(not ns.gear.isCarried(6529), "Removing a lure must invalidate current carry status")
assert(not ns.gear.set("lure", 6529), "Cannot reselect a no-longer-owned lure")
assert(ns.gear.profile().lure == 6529, "Remember preference without pretending it is carried")
print("inventory-based fishing gear preference tests passed")
