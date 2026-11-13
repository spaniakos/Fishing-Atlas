-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {}}
assert(loadfile("FishingAtlas/Data/ReferenceVendors.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Data/ReferenceFishZones.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Data/ZoneSkill.lua"))("FishingAtlas", ns)
local vendors, zoneFish = ns.data.referenceVendors, ns.data.referenceZoneFish
assert(#vendors >= 90, "Expected the fishing seller and trainer source set")
local seller, trainer, seenNPCs = 0, 0, {}
for _, v in ipairs(vendors) do
  assert(v.id > 0 and not seenNPCs[v.id])
  seenNPCs[v.id] = true
  assert(v.verifiedInGame == false)
  if v.trainer then trainer = trainer + 1 end
  if #v.items > 0 then seller = seller + 1 end
  for _, p in ipairs(v.spots) do
    assert(p.mapID > 0 and p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1)
  end
end
assert(seller >= 70 and trainer >= 20)
local n = 0
for mapID, fish in pairs(zoneFish) do
  n = n + 1
  assert(type(mapID) == "number")
  for _, f in ipairs(fish) do
    assert(type(f.id) == "number" and type(f.evidence) == "string")
  end
end
assert(n >= 40)
assert(zoneFish[2521][1].evidence == "luredon_player_recorded")
assert(ns.data.zoneFishingSkill[1434].minimum == 126)
print("sourced fishing reference data tests passed")
