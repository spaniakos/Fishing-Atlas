-- SPDX-License-Identifier: GPL-3.0-or-later
-- Independent published fishing-guide location leads. GUIDE REFERENCES ONLY.
-- Not corroborated spawn observations; positions describe investigated areas,
-- never a guarantee a pool is active. No fabricated live Forever verification.
local _, ns = ...
local guide = "https://wowforever.gg/en/professions/fishing/"
ns.data.referenceSchoolLocations = {
  ["School of Deviate Fish"] = {
    {mapID = 1413, x = 0.4506, y = 0.2219, source = "guide_reference", url = guide},
    {mapID = 1413, x = 0.4547, y = 0.2272, source = "guide_reference", url = guide},
    {mapID = 1413, x = 0.4467, y = 0.2357, source = "guide_reference", url = guide},
    {mapID = 1413, x = 0.4511, y = 0.2364, source = "guide_reference", url = guide},
    {mapID = 1413, x = 0.4634, y = 0.3762, source = "guide_reference", url = guide}
  },
  ["School of Sagefish"] = {
    {mapID = 1424, x = 0.6053, y = 0.3030, source = "guide_reference", url = guide},
    {mapID = 1424, x = 0.6024, y = 0.3193, source = "guide_reference", url = guide},
    {mapID = 1424, x = 0.6166, y = 0.3219, source = "guide_reference", url = guide},
    {mapID = 1424, x = 0.6080, y = 0.3413, source = "guide_reference", url = guide},
    {mapID = 1424, x = 0.7126, y = 0.1006, source = "guide_reference", url = guide}
  }
}
