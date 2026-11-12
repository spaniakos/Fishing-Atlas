-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/Core/Namespace.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Core/Storage.lua"))("FishingAtlas", ns)
FishingAtlasDB = {
  schemaVersion = 1,
  observations = {{id = "legacy:1", label = "My Old Spot", mapID = 1411, x = 0.3, y = 0.4}},
  settings = {notifications = "broken", radiusPercent = -100},
  catches = {x = {name = "Fish", count = 5}},
  schoolCandidates = {"corrupt"},
  vendorObservations = "garbled",
}
assert(ns.storage.init())
assert(ns.storage.db.schemaVersion == 3)
assert(ns.storage.db.settings.notifications == true)
assert(ns.storage.db.settings.radiusPercent == 1)
assert(ns.storage.db.observations[1].label == "My Old Spot")
assert(ns.storage.db.catches.x.count == 5)
assert(type(ns.storage.db.vendorObservations) == "table")
assert(ns.storage.count() == 1)
assert(ns.storage.inZone(1411)[1].label == "My Old Spot")
print("migration tests passed")
