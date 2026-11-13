-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/UI/ZoneMap.lua"))("FishingAtlas", ns)
local layout = ns.zoneMap.layout({layerWidth = 512, layerHeight = 256,
  tileWidth = 256, tileHeight = 256}, {101, 102}, 256, 128)
assert(#layout == 2)
assert(layout[1].texture == 101 and layout[2].texture == 102)
assert(layout[1].x == 0 and layout[2].x == 128)
assert(layout[1].w == 128 and layout[1].h == 128)
assert(#ns.zoneMap.layout({}, {}, 100, 100) == 0)
assert(#ns.zoneMap.layout({layerWidth=256,layerHeight=256,
  tileWidth=128,tileHeight=128}, {1,2,3,4}, 256, 256) == 4)
print("WoW map tile layout tests passed")
