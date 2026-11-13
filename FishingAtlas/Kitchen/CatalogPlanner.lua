-- SPDX-License-Identifier: GPL-3.0-or-later
-- Build-driven ingredient requirements; acquisition availability remains unconfirmed.
local _, ns = ...
local K = ns.kitchen

function K.catalogPlan(spellId, crafts, itemCounts)
  local recipe = ns.catalog.recipe(spellId)
  if not recipe then return nil, "Unknown recipe spell" end
  crafts = tonumber(crafts) or 1
  if crafts < 1 or crafts > 100 or crafts ~= math.floor(crafts) then
    return nil, "Invalid craft count"
  end
  local result = {
    spellId = recipe.spellId,
    profession = recipe.profession,
    name = ns.catalog.name("spell", recipe.spellId),
    output = recipe.outputItemId and ns.catalog.name("item", recipe.outputItemId) or "No item output",
    minimumSkill = recipe.cookingSkill,
    crafts = crafts,
    reagents = {},
    verifiedInGame = false,
  }
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    local owned = 0
    if type(itemCounts) == "table" then
      owned = tonumber(itemCounts[ingredient.itemId]) or 0
    elseif type(C_Item) == "table" and type(C_Item.GetItemCount) == "function" then
      owned = tonumber(C_Item.GetItemCount(ingredient.itemId, true)) or 0
    end
    owned = math.max(0, owned)
    local needed = ingredient.amount * crafts
    result.reagents[#result.reagents + 1] = {
      itemId = ingredient.itemId,
      name = ns.catalog.name("item", ingredient.itemId),
      need = needed,
      owned = owned,
      missing = math.max(0, needed - owned)
    }
  end
  return result
end
