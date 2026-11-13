-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {kitchen = {}}
ns.catalog = {
  recipe = function(id)
    if tonumber(id) == 18243 then return {
      spellId = 18243, outputItemId = 13931, profession = "Cooking", cookingSkill = 250,
      ingredients = {{itemId = 13759, amount = 1}, {itemId = 159, amount = 1}}
    } end
  end,
  name = function(kind, id) return kind .. " #" .. id end
}
assert(loadfile("FishingAtlas/Kitchen/CatalogPlanner.lua"))("FishingAtlas", ns)
local plan = assert(ns.kitchen.catalogPlan(18243, 3, {[13759] = 2, [159] = 5}))
assert(plan.crafts == 3 and plan.minimumSkill == 250)
assert(plan.reagents[1].missing == 1 and plan.reagents[2].missing == 0)
assert(not ns.kitchen.catalogPlan(123, 1))
assert(not ns.kitchen.catalogPlan(18243, 0))
assert(not ns.kitchen.catalogPlan(18243, 101))
C_Item = {GetItemCount = function(id, bank)
  assert(bank == true)
  if id == 13759 then return 2 end
  return 0
end}
local clientPlan = assert(ns.kitchen.catalogPlan(18243, 3))
assert(clientPlan.reagents[1].owned == 2 and clientPlan.reagents[1].missing == 1)
print("catalog planner tests passed")
