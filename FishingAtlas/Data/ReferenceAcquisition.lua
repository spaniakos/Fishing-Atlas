-- SPDX-License-Identifier: GPL-3.0-or-later
-- Historical/public references for fishing gear acquisition. These are not
-- player-verified on the current Forever server. Never invent a drop rate or
-- exact world coordinate from a quest region or historical loot source.
local _, ns = ...
ns.data.referenceAcquisition = {
  [6367] = {
    {kind = "object_loot", title = "Shellfish Trap",
      note = "Underwater shellfish trap object loot near Shadowprey Village, Desolace",
      mapID = 1443, confidence = "classic_reference",
      url = "https://warcraft.wiki.gg/wiki/Big_Iron_Fishing_Pole"}
  },
  [6811] = {
    {kind = "crafted", title = "Engineering (150) craft",
      note = "Requires engineering reagents; historically made 3 per craft. Vendors may offer limited stock.",
      confidence = "classic_reference",
      url = "https://warcraft.wiki.gg/wiki/Aquadynamic_Fish_Attractor"}
  },
  [7307] = {
    {kind = "creature_drop", title = "Rotted One",
      note = "Historical creature loot, Duskwood; no verified Forever probability or spawn coordinate",
      mapID = 1431, confidence = "classic_reference",
      url = "https://senseos.gg/wiki/wow-forever/items/7307/flesh-eating-worm/"}
  },
  [12225] = {
    {kind = "quest_reward", title = "The Family and the Fishing Pole",
      note = "Quest #1141 reward; Darkshore. Confirm reward in the current Forever client.",
      questId = 1141, mapID = 1439, confidence = "classic_reference",
      url = "https://db.icy-veins.com/wow-forever/items/12225"}
  },
  [19022] = {
    {kind = "quest_reward", title = "Snapjaws, Mon!",
      note = "Quest #7815 reward, Horde, Hinterlands. Classic and Forever client references.",
      questId = 7815, mapID = 1425, confidence = "classic_reference",
      url = "https://db.icy-veins.com/wow-forever/items/19022"}
  },
  [19970] = {
    {kind = "quest_reward", title = "Master Angler",
      note = "Quest #8193 reward, Stranglethorn Fishing Extravaganza",
      questId = 8193, mapID = 1434, confidence = "classic_reference",
      url = "https://www.forever-xp.com/quests/8193/"}
  }
}
