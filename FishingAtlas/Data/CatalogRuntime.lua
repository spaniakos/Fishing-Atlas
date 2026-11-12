-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.catalog = {}
local C = ns.catalog
local data = ns.data.catalog or {}
local byKind, bySpell = {}, {}
for _, entity in ipairs(data.entities or {}) do
  if not byKind[entity.type] then byKind[entity.type] = {} end
  byKind[entity.type][entity.id] = entity
end
for _, recipe in ipairs(data.recipes or {}) do bySpell[recipe.spellId] = recipe end

function C.entity(kind, id)
  return byKind[kind] and byKind[kind][tonumber(id)] or nil
end
function C.recipe(id)
  return bySpell[tonumber(id)]
end
function C.name(kind, id)
  id = tonumber(id)
  if not id then return "Unknown" end
  if kind == "item" and type(GetItemInfo) == "function" then
    local name = GetItemInfo(id)
    if type(name) == "string" and name ~= "" then return name, true end
  elseif kind == "spell" and type(GetSpellInfo) == "function" then
    local name = GetSpellInfo(id)
    if type(name) == "string" and name ~= "" then return name, true end
  end
  local item = C.entity(kind, id)
  if item and type(item.name) == "string" and not item.name:match("^Item #")
    and not item.name:match("^Spell #") then return item.name, false end
  return (kind == "spell" and "Unresolved spell #" or "Unresolved item #") .. id, false
end
function C.stats()
  local n = {items = 0, spells = 0, recipes = 0, cooking = 0, fishing = 0}
  for _, entry in ipairs(data.entities or {}) do
    if entry.type == "item" then n.items = n.items + 1
    elseif entry.type == "spell" then n.spells = n.spells + 1 end
  end
  for _, recipe in ipairs(data.recipes or {}) do
    n.recipes = n.recipes + 1
    if recipe.profession == "Cooking" then n.cooking = n.cooking + 1 end
    if recipe.profession == "Fishing" then n.fishing = n.fishing + 1 end
  end
  return n
end
