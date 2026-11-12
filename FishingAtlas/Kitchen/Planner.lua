-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.kitchen = {}
local K = ns.kitchen
local recipes = ns.data.recipes or {}
function K.get(id)
  if type(id) ~= "string" then return nil end
  id = id:lower()
  for _, recipe in ipairs(recipes) do if recipe.id == id then return recipe end end
  return nil
end
function K.search(term)
  term = type(term) == "string" and term:lower() or ""
  local list = {}
  for _, recipe in ipairs(recipes) do
    if recipe.name:lower():find(term, 1, true) or recipe.output:lower():find(term, 1, true)
      or recipe.id:find(term, 1, true) then list[#list + 1] = recipe end
  end
  return list
end
function K.missing(recipe, counts)
  if type(recipe) ~= "table" or type(recipe.ingredients) ~= "table" then return {} end
  counts = counts or {}
  local missing = {}
  for _, ingredient in ipairs(recipe.ingredients) do
    local owned = tonumber(counts[ingredient.name]) or 0
    local needed = math.max(0, ingredient.amount - math.max(0, owned))
    if needed > 0 then missing[#missing + 1] = {name = ingredient.name, amount = needed} end
  end
  return missing
end
