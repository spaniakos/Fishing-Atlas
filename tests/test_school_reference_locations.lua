-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {}}
assert(loadfile("FishingAtlas/Data/ReferenceSchoolLocations.lua"))("FishingAtlas", ns)
local sources = ns.data.referenceSchoolLocations
assert(#sources["School of Deviate Fish"] == 5)
assert(#sources["School of Sagefish"] == 5)
for school, places in pairs(sources) do
  for _, loc in ipairs(places) do
    assert(loc.mapID == 1413 or loc.mapID == 1424, school)
    assert(loc.x > 0 and loc.x < 1 and loc.y > 0 and loc.y < 1)
    assert(loc.source == "guide_reference")
    assert(type(loc.url) == "string" and loc.url:find("wowforever.gg", 1, true))
  end
end
print("attributed school guide location tests passed")
