-- SPDX-License-Identifier: GPL-3.0-or-later
-- Contract: pinned Forever observations remain distinct from Classic refs.
local ns = {data = {}}
assert(loadfile("FishingAtlas/Data/ForeverObservedCooking.lua"))("FishingAtlas", ns)
local d = ns.data.foreverObservedCooking
assert(d.meta.license == "CC BY 4.0")
assert(d.meta.sourceCommit == "ea970da071079b32e56f349e09648ff0e314b351")
local count, vendorRows, trainerRows = 0, 0, 0
for _, rows in pairs(d.vendors) do
  count = count + 1
  vendorRows = vendorRows + #rows
end
for _, rows in pairs(d.trainers) do trainerRows = trainerRows + #rows end
assert(count == 49 and vendorRows == 94 and trainerRows == 72,
  "Observed source snapshot counts must remain reproducible")
local crispy = d.vendors["crispy bat wing"]
assert(#crispy > 0 and crispy[1].itemId == 12226
  and crispy[1].npcId == 2118 and crispy[1].mapID == 1420
  and crispy[1].sourceBuild == "1.60.1.70862")
local smallfish = d.vendors["brilliant smallfish"]
local found = false
for _, row in ipairs(smallfish) do
  if row.itemId == 6325 and row.sourceBuild == "1.60.1.70938"
      and (row.npcId == 66 or row.npcId == 3550) then found = true end
end
assert(found, "Build 70938 must retain real Brilliant Smallfish inventory")
assert(d.trainers["2541"][1].skillRank == 50,
  "Cooking requirements must come from actual trainer menu evidence")
print("pinned EG Link Cooking data, licensing and named source tests passed")
