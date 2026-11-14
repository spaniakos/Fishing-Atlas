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

-- A client with no IsFishingLoot API must still classify a recent cast.
local now = 100
GetTime = function() return now end
IsFishingLoot = nil
GetNumLootItems = function() return 1 end
GetLootSlotInfo = function() return nil, "Raw Brilliant Smallfish", 2 end
GetLootSlotLink = function()
  return "|cff00ff00|Hitem:6291:0:0|h[Raw Brilliant Smallfish]|h|r"
end
GetSpellInfo = function(id) if id == 7620 then return "Fishing" end end
assert(ns.loot.noteCast(nil, 7620),
  "Client spellcast events can carry numeric spell IDs after nil arguments")
assert(ns.loot.open(), "Recent fishing casts must classify a loot window")
ns.loot.closed()
assert(ns.loot.chat("You receive loot: |cff00ff00|Hitem:6291:0:0|h[Raw Brilliant Smallfish]|h|r."))
assert(ns.journal.total() == 9,
  "Auto loot must record when LOOT_SLOT_CLEARED is absent")
assert(not ns.loot.chat("You receive loot: |Hitem:6291|h[Raw Brilliant Smallfish]|h"),
  "Repeated CHAT_MSG_LOOT must not double count")
assert(ns.loot.open())
ns.loot.cleared(1)
assert(ns.journal.total() == 11)
assert(not ns.loot.chat("You receive loot: |Hitem:6291|h[Raw Brilliant Smallfish]|h"),
  "Slot cleared plus loot chat must not count twice")
now = 200
assert(not ns.loot.open(), "An expired cast must not record unrelated loot")
ns.loot.cleared(1)
assert(not ns.loot.chat("You receive loot: |Hitem:6291|h[Raw Brilliant Smallfish]|h"),
  "Unrelated item collection must never be called a fishing catch")
assert(ns.journal.total() == 11)
assert(ns.journal.unique() == 2)
assert(ns.loot.debug():find("chat confirmations 1", 1, true))
print("autoloot journal fallback and no-double-count tests passed")

