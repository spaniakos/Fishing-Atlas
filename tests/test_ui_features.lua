-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {schoolTypes={}}, storage = {db = {settings = {showMinimap = true, minimapAngle = 0}}}}
assert(loadfile("FishingAtlas/UI/Minimap.lua"))("FishingAtlas", ns)
local x, y = ns.minimap.coordinates(0)
assert(math.abs(x - 80) < 0.0001 and math.abs(y) < 0.0001)
local x2, y2 = ns.minimap.coordinates(90)
assert(math.abs(x2) < 0.0001 and math.abs(y2 - 80) < 0.0001)
assert(loadfile("FishingAtlas/UI/Options.lua"))("FishingAtlas", ns)
assert(ns.options and ns.options.start and ns.options.open)
local catalog = {icon = function(_, id) return "icon:" .. id end,
  recipe = function() return {outputItemId = 13931} end}
ns.catalog = catalog
assert(loadfile("FishingAtlas/UI/Browser.lua"))("FishingAtlas", ns)
assert(ns.browser.icon({kind = "fish", id = 13759}) == "icon:13759")
assert(ns.browser.icon({kind = "Cooking", id = 18243}) == "icon:13931")
local kind, id = ns.browser.tooltip({kind = "fish", id = 13759})
assert(kind == "item" and id == 13759)
assert(ns.browser.tooltip({kind = "zone", id = 1411}) == nil)
print("UI feature model tests passed")
