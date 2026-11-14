-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {data = {}, util = {validCoordinate = function(v)
  return type(v) == "number" and v >= 0 and v <= 1
end}}
assert(loadfile("FishingAtlas/Data/RecipeIndex.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Kitchen/RecipeRepository.lua"))("FishingAtlas", ns)
local R = ns.recipeRepository
assert(R.coverage().total == 136)
assert(#R.list() == 136)
assert(#R.conflicts() == 0)
local crispy = R.get(15935)
assert(crispy.professionId == 185 and crispy.spellId == 15935)
assert(crispy.output.itemId == 12224 and crispy.reagents[1].itemId == 12223)
assert(crispy.teachingItems[1].itemId == 12226)
assert(R.learnRank(15935).rank == 1)
local abigail = false
for _, source in ipairs(R.sources(15935)) do
  if source.relation == "vendor_sells_item" and source.npcId == 2118
      and source.itemId == 12226 then abigail = true end
end
assert(abigail, "Vendor/recipe source edges require exact teaching item IDs")
assert(R.learnRank(2541).rank == 50)
assert(R.get(2541).teachingItems[1] == nil,
  "Observed trainer is not an invented teaching scroll")
assert(R.get(2795).teachingItems[1].itemId == 2889)
assert(R.get(18243).skills.learn.rank == 250)
assert(R.get(18243).skills.yellow.rank == 290)
local unknown = R.get(818)
assert(unknown.skills.learn == nil and #unknown.teachingItems == 0,
  "Client minimumSkill=1 may not fabricate a required learn rank")
assert(R.get(999999) == nil)
local personal = {[999999] = {id = 999999, name = "Personal reference",
  profession = "Cooking", source = "personal_reference"}}
ns.recipeDiscovery = {get = function(id) return personal[id] end,
  list = function() return {personal[999999]} end}
assert(R.get(999999).skills.learn == nil)
assert(#R.list() == 137 and #R.sources(999999) == 0,
  "Personal references should merge without modifying compiled game data")
assert(R.coverage().total == 136,
  "Coverage must describe bundled source data, not user-added references")
print("Recipes v2 typed repository, identity links and safe fallback passed")
