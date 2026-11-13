-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
-- Zone-wide fishing skills from Wowhead Forever fishing guide, accessed 2026-11-13.
-- Sub-zones may differ; values are reference guides, NOT independently confirmed in game.
-- Source: https://www.wowhead.com/forever/guide/professions/fishing/overview-leveling
ns.data.zoneFishingSkill = {}
local skill = ns.data.zoneFishingSkill
local groups = {
  {1,25,{1411,1412,1420,1426,1429,1438}},
  {1,75,{1413,1421,1432,1436,1439,1453,1454,1455,1456,1457,1458}},
  {55,150,{1424,1431,1433,1437,1440,1442}},
  {130,225,{1416,1417,1434,1435,1441,1443,1445}},
  {205,300,{1422,1425,1444,1446,1447,1448,1449,1450}},
  {330,425,{1423,1428,1430,1451,1452}}
}
for _, group in ipairs(groups) do
  for _, mapID in ipairs(group[3]) do
    skill[mapID] = {
      minimum = group[1], reliable = group[2],
      source = "wowhead_forever_guide", verifiedInGame = false,
    }
  end
end
-- Maps with uncertain zone-wide rules (e.g., Badlands, Blasted Lands,
-- Searing Gorge) intentionally remain unknown rather than inventing a number.
local exceptions = {
  [1434] = "Jaguero Isle: 205 minimum / 300 reliable",
  [1444] = "Jademir Lake: 330 minimum / 425 reliable",
  [1447] = "Bay of Storms, Hetaera's Clutch, Scalebeard's Cave: 330 / 425",
}
for mapID, note in pairs(exceptions) do skill[mapID].exceptions = note end
