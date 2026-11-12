-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.guides = {}
function ns.guides.fishSearch(term)
  term = type(term) == "string" and term:lower() or ""
  local found = {}
  for _, fish in ipairs(ns.data.fish or {}) do
    if fish.name:lower():find(term, 1, true) then found[#found + 1] = fish end
  end
  return found
end
function ns.guides.relatedRecipes(fishName)
  if type(fishName) ~= "string" then return {} end
  local found = {}
  for _, recipe in ipairs(ns.data.recipes or {}) do
    for _, ingredient in ipairs(recipe.ingredients or {}) do
      if ingredient.name == fishName then found[#found + 1] = recipe; break end
    end
  end
  return found
end
