-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {}}
assert(loadfile("FishingAtlas/Data/Recipes.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Kitchen/Planner.lua"))("FishingAtlas", ns)
assert(#ns.kitchen.search("nightfin") == 1)
assert(#ns.kitchen.search("") == 3)
assert(ns.kitchen.get("nightfin-soup").skill == 250)
assert(not ns.kitchen.get("not-a-recipe"))
local soup = ns.kitchen.get("nightfin-soup")
local missing = ns.kitchen.missing(soup, {["Raw Nightfin Snapper"] = 3})
assert(#missing == 1 and missing[1].name == "Refreshing Spring Water")
assert(#ns.kitchen.missing(soup, {["Raw Nightfin Snapper"] = 3, ["Refreshing Spring Water"] = 2}) == 0)
print("kitchen tests passed")
