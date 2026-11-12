-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {}}
for _, file in ipairs({
  "Core/Namespace.lua", "Core/Storage.lua", "Data/Fish.lua", "Data/Recipes.lua",
  "Atlas/Routes.lua", "Guides/Search.lua"
}) do assert(loadfile("FishingAtlas/" .. file))("FishingAtlas", ns) end
FishingAtlasDB = nil
assert(ns.storage.init())
assert(ns.storage.add(1, 0.1, 0.1, "Blue"))
assert(ns.storage.add(1, 0.9, 0.9, "Red"))
assert(ns.storage.add(1, 0.2, 0.2, "Blue"))
local route = ns.routes.plan(1, 0, 0, "blue")
assert(#route == 2 and route[1].node.x == 0.1)
assert(#ns.routes.plan(2, 0, 0) == 0)
assert(#ns.guides.fishSearch("nightfin") == 1)
assert(#ns.guides.relatedRecipes("Raw Nightfin Snapper") == 1)
assert(#ns.guides.relatedRecipes("Unknown") == 0)
print("guide and route tests passed")
