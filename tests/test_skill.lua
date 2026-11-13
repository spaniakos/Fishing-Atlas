-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {}}
assert(loadfile("FishingAtlas/Data/ZoneSkill.lua"))("FishingAtlas", ns)
local s = ns.data.zoneFishingSkill
assert(s[1411].minimum == 1 and s[1411].reliable == 25)
assert(s[1434].minimum == 126 and s[1434].exceptions)
assert(s[1447].minimum == 205 and s[1447].exceptions)
assert(s[1452].minimum == 330 and s[1452].reliable == 425)
assert(s[1418] == nil)
print("zone fishing skill tests passed")
