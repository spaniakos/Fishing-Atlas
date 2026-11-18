-- SPDX-License-Identifier: GPL-3.0-or-later
-- Test the actual LibStub provider contract with missing, incomplete and wrong-game libraries.
local ns = {}
assert(loadfile("FishingAtlas/Providers/ItemProvider.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Providers/ProfessionProvider.lua"))("FishingAtlas", ns)
assert(not ns.itemProvider.status())
assert(not ns.professionProvider.status())
assert(not ns.itemProvider.name(6529))
assert(not ns.professionProvider.requirement(18243))

local version = "Vanilla"
local ready = true
local itemLib = {
  IsReady = function() return ready end,
  GetGameVersion = function() return version end,
  GetName = function(_, id) if id == 6529 then return "Shiny Bauble" end end,
  GetLink = function(_, id) return "|cffaaa|Hitem:" .. id .. "|h[Item]|h|r" end
}
local professionLib = {
  IsReady = function() return ready end,
  GetGameVersion = function() return version end,
  GetRequiredSkill = function(_, id) if id == 18243 then return 250 end end,
  GetRecipeItem = function(_, id) if id == 18243 then return 13945, false end end,
  GetReagents = function() return {{itemId = 13759, amount = 1}} end,
  IsBorrowed = function() return false end,
}
LibStub = function(name)
  if name == "LibItemDB-1.0" then return itemLib end
  if name == "LibProfessionDB-1.0" then return professionLib end
end
assert(not ns.itemProvider.status() and not ns.professionProvider.status(),
  "Vanilla data must never impersonate Forever")
assert(not ns.itemProvider.name(6529))
version = "Forever"
assert(ns.itemProvider.status() and ns.professionProvider.status())
assert(ns.itemProvider.name(6529) == "Shiny Bauble")
assert(ns.itemProvider.link(6529):find("|Hitem:", 1, true))
local skill, source = ns.professionProvider.requirement(18243)
assert(skill == 250 and source == "libprofessiondb_forever")
assert(ns.professionProvider.teachingItem(18243) == 13945)
assert(#ns.professionProvider.reagents(18243) == 1)
professionLib.IsBorrowed = function() return true end
assert(select(2, ns.professionProvider.requirement(18243)) == "borrowed_classic_reference")
professionLib.GetRecipeItem = function() return 9999, true end
assert(not ns.professionProvider.teachingItem(18243), "Skill-rank books are not recipe scrolls")
itemLib.GetName = function() error("broken library") end
assert(not ns.itemProvider.name(6529), "Broken library must not crash Atlas")
professionLib.GetRequiredSkill = function() error("broken library") end
assert(not ns.professionProvider.requirement(18243), "Broken recipe API must not crash Atlas")
ready = false
assert(not ns.itemProvider.status() and not ns.professionProvider.status())
ready = true
itemLib.GetGameVersion = nil
assert(not ns.itemProvider.status(), "Unverifiable game flavour cannot be authoritative")
LibStub = nil
assert(not ns.itemProvider.status() and not ns.professionProvider.status())
print("optional Forever library provider guards and fallback tests passed")
