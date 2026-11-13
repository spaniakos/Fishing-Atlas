-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {catalog = {
  entities = {{type="item",id=13759,name="Item #13759"},
    {type="spell",id=18243,name="Spell #18243"}},
  recipes = {{spellId=18243,profession="Cooking",professionId=185,
    outputItemId=13931,cookingSkill=250,ingredients={{itemId=13759,amount=1}}}}
}}}
local itemDB = {
  IsReady = function() return true end,
  GetName = function(_, id) return id == 13759 and "Offline Nightfin Snapper" or nil end,
  GetLink = function(_, id) return id == 13759 and "|Hitem:13759|h[Nightfin]|h" or nil end
}
local professionDB = {
  IsReady = function() return true end,
  GetGameVersion = function() return "Forever" end,
  GetRecipe = function(_, professionID, id)
    assert(professionID == 185 and id == 18243)
    return {name="Nightfin Soup",sources={{kind="trainer",id=101}},
      requiredSkill=175, difficulty={150,175,195,215},
      craftedItemId=13931, reagents={{13759,1}}}
  end,
  GetBorrowed = function() return {sources="Vanilla", requiredSkill="Vanilla"} end
}
LibStub = function(name)
  if name == "LibItemDB-1.0" then return itemDB end
  if name == "LibProfessionDB-1.0" then return professionDB end
  return nil
end
assert(loadfile("FishingAtlas/Data/CatalogRuntime.lua"))("FishingAtlas", ns)
assert(ns.catalog.externalLibraryAvailable("LibItemDB-1.0"))
assert(not ns.catalog.externalLibraryAvailable("invented-library"))
local name, live = ns.catalog.name("item", 13759)
assert(name == "Offline Nightfin Snapper" and live == false)
assert(ns.catalog.itemLink(13759) == "|Hitem:13759|h[Nightfin]|h")
local record, meta = ns.catalog.professionRecord(18243)
assert(record.name == "Nightfin Soup")
assert(meta.source == "libprofessiondb_forever_client")
assert(meta.verifiedInForeverClient == true and meta.verifiedLiveServer == false)
assert(record.sources == nil and record.requiredSkill == nil)
assert(record.craftedItemId == 13931 and record.difficulty[1] == 150)
assert(ns.catalog.recipe(18243).cookingSkill == 250)
C_Item = {GetItemInfo = function() return "Client Nightfin Snapper" end}
local clientName, clientLive = ns.catalog.name("item", 13759)
assert(clientName == "Client Nightfin Snapper" and clientLive == true)
C_Item = nil
itemDB.IsReady = function() return false end
assert(ns.catalog.name("item", 13759) == "Unresolved item #13759")
assert(ns.catalog.itemLink(13759) == nil)
professionDB.IsReady = function() return false end
assert(ns.catalog.professionRecord(18243) == nil)
professionDB.IsReady = function() return true end
professionDB.GetGameVersion = function() return "Vanilla" end
assert(ns.catalog.professionRecord(18243) == nil)
professionDB.GetGameVersion = function() return "Forever" end
professionDB.GetBorrowed = nil
assert(ns.catalog.professionRecord(18243) == nil)
itemDB.IsReady = function() error("stale addon library") end
assert(ns.catalog.name("item", 13759) == "Unresolved item #13759")
LibStub = nil
assert(ns.catalog.name("item", 13759) == "Unresolved item #13759")
assert(ns.catalog.professionRecord(18243) == nil)
print("optional Forever offline-library bridge tests passed")
