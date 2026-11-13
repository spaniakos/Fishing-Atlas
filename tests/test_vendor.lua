-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Core/Namespace.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Core/Storage.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Data/VendorObservations.lua"))("FishingAtlas", ns)
FishingAtlasDB = nil
assert(ns.storage.init())
local guid = "Creature-0-0-0-0-12345-00000001"
assert(ns.vendors.npcId(guid) == 12345)
assert(ns.vendors.npcId("Player-123-456") == nil)
local good, npc = ns.vendors.capture(guid, {"|cffffff|Hitem:13759:0|h[Fish]|h|r", "|Hitem:13759:0|h[Fish]|h"}, 100)
assert(good and npc == 12345)
local item = ns.storage.db.vendorObservations[12345]
assert(#item.items == 1 and item.items[1] == 13759 and item.sightings == 1)
assert(not ns.vendors.capture("Player-123-456", {"|Hitem:13759|h"}, 100))
assert(not ns.vendors.capture(guid, {"invalid"}, 100))
assert(ns.vendors.capture(guid, {"|Hitem:6256|h[Pole]|h"}, 200,
  {mapID = 1411, x = 0.3, y = 0.5}, "Vendor Test"))
assert(item.mapID == 1411 and item.x == 0.3 and item.precision == "player_position_at_merchant")
assert(item.name == "Vendor Test")
print("vendor capture tests passed")
