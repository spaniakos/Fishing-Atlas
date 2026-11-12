-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Core/Namespace.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Core/Storage.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Collect/Journal.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Collect/Loot.lua"))("FishingAtlas", ns)
FishingAtlasDB = nil
assert(ns.storage.init())
assert(not ns.journal.record(nil, "", 1))
assert(not ns.journal.record(1, "Fish", 0))
assert(not ns.journal.record(1, "Fish", 201))
assert(ns.journal.record(10, "Fish", 2, "manual"))
assert(ns.journal.record(10, "Fish", 3, "manual"))
assert(ns.journal.total() == 5 and ns.journal.unique() == 1)
IsFishingLoot = function() return true end
GetNumLootItems = function() return 1 end
GetLootSlotInfo = function() return nil, "Fish", 2 end
GetLootSlotLink = function() return "|cff|Hitem:10:0:0|h[Fish]|h|r" end
ns.loot.open()
ns.loot.cleared(1)
ns.loot.cleared(1)
assert(ns.journal.total() == 7)
IsFishingLoot = function() return false end
ns.loot.open()
ns.loot.cleared(1)
assert(ns.journal.total() == 7)
print("catch journal tests passed")
