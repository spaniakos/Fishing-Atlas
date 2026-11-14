-- SPDX-License-Identifier: GPL-3.0-or-later
-- Historical item acquisition references, not observations on WoW Forever.
-- No invented game-object coordinates or drop percentages.
local _, ns = ...
ns.data.referenceAcquisition = {
  [6367] = {
    {kind = "object_loot", title = "Shellfish Trap",
      note = "Underwater trap loot near Shadowprey Village; historical Classic source",
      mapID = 1443, -- Desolace; zone-level only, NOT a pin or object spawn
      confidence = "classic_reference",
      source = "Warcraft Wiki",
      url = "https://warcraft.wiki.gg/wiki/Big_Iron_Fishing_Pole"}
  }
}
