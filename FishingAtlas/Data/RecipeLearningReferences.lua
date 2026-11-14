-- SPDX-License-Identifier: GPL-3.0-or-later
-- Version-stamped, small, explicitly attributed public Forever cooking references.
-- These are PUBLIC REFERENCE LEADS; neither NPC inventory nor quest availability
-- is asserted observed/confirmed on the player's current Forever server.
-- Cooking spell IDs are not the item IDs of recipe scrolls used to learn them.
local _, ns = ...
ns.data.recipeLearningReferences = {
  [2795] = {
    minimumSkill = 25, recipeItemId = 2889,
    recipeItemName = "Recipe: Beer Basted Boar Ribs",
    source = "forever_client_public_reference", sourceBuild = "1.60.1.70862",
    url = "https://zephras.com/forever/enUS/spell/2795/",
    sources = {
      {kind = "vendor", npcId = 340, label = "Kendor Kabonka",
        zone = "Stormwind City", mapID = 1453, x = 0.775, y = 0.527,
        source = "classic_vendor_reference",
        url = "https://metabot.gg/en/wow-forever/items/recipe-beer-basted-boar-ribs"},
      {kind = "quest", questId = 384, label = "Beer Basted Boar Ribs",
        giver = "Ragnar Thunderbrew", zone = "Dun Morogh",
        mapID = 1426, x = 0.468, y = 0.524, source = "classic_quest_reference",
        url = "https://www.forever-xp.com/quests/384/"}
    }
  },
  [18247] = {
    minimumSkill = 275, recipeItemId = 13949,
    recipeItemName = "Recipe: Baked Salmon",
    source = "forever_client_public_reference", sourceBuild = "1.60.1.70862",
    url = "https://www.foreverdb.app/en/forever/items/13949/recipe-baked-salmon",
    sources = {
      {kind = "vendor", label = "Vivianna", zone = "Feralas",
        mapID = 1444, x = 0.313, y = 0.435,
        source = "cmangos_classic_reference"},
      {kind = "vendor", label = "Sheendra Tallgrass", zone = "Feralas",
        mapID = 1444, x = 0.745, y = 0.427,
        source = "cmangos_classic_reference"}
    }
  },
  [7751] = {
    minimumSkill = 1, recipeItemId = 6325,
    recipeItemName = "Recipe: Brilliant Smallfish",
    source = "forever_client_public_reference", sourceBuild = "1.60.1.70862",
    url = "https://www.foreverdb.app/en/forever/items/6325/recipe-brilliant-smallfish",
    sources = {
      {kind = "vendor", label = "Gretta Ganter", npcId = 8508,
        zone = "Dun Morogh", mapID = 1426, x = 0.315, y = 0.447,
        source = "foreverdb_vendor_reference"}
    }
  },
  [7753] = {
    minimumSkill = 50, recipeItemId = 6328,
    recipeItemName = "Recipe: Longjaw Mud Snapper",
    source = "forever_client_public_reference", sourceBuild = "1.60.1.70938",
    url = "https://forever-tavern.com/items/6328-recipe-longjaw-mud-snapper/",
    sources = {
      {kind = "vendor", label = "Harn Longcast", npcId = 5940,
        zone = "Mulgore", mapID = 1412, x = 0.467, y = 0.592,
        source = "classic_vendor_reference"}
    }
  }
}
