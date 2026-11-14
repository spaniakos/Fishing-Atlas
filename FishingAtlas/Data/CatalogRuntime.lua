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
  if kind == "item" and type(C_Item) == "table" and type(C_Item.GetItemInfo) == "function" then
    local name = C_Item.GetItemInfo(id)
    if type(name) == "string" and name ~= "" then return name, true end
  elseif kind == "spell" and type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
    local info = C_Spell.GetSpellInfo(id)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      return info.name, true
    end
  end
  if kind == "item" and ns.sources and ns.sources.itemName then
    local fromObserved = ns.sources.itemName(id)
    if type(fromObserved) == "string" and fromObserved ~= "" then return fromObserved, false end
  end
  local item = C.entity(kind, id)
  if item and type(item.name) == "string" and not item.name:match("^Item #")
    and not item.name:match("^Spell #") then return item.name, false end
  if kind == "item" then
    for _, ref in pairs(ns.data.recipeLearningReferences or {}) do
      if ref.recipeItemId == id and type(ref.recipeItemName) == "string" then
        return ref.recipeItemName, false
      end
    end
  end
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

function C.search(term, kind, category, limit)
  term = type(term) == "string" and term:lower() or ""
  if #term < 2 then return {} end
  limit = math.min(tonumber(limit) or 20, 50)
  local matches = {}
  for _, entity in ipairs(data.entities or {}) do
    if (not kind or kind == entity.type) and (not category or category == entity.category) then
      local label = C.name(entity.type, entity.id)
      if label:lower():find(term, 1, true) or tostring(entity.id) == term then
        matches[#matches + 1] = {id = entity.id, kind = entity.type,
          name = label, category = entity.category, confidence = entity.confidence}
      end
      if #matches >= limit then break end
    end
  end
  return matches
end
function C.byCategory(category, limit)
  local output = {}
  limit = math.min(tonumber(limit) or 20, 100)
  for _, entity in ipairs(data.entities or {}) do
    if entity.category == category then
      output[#output + 1] = {id = entity.id, name = C.name(entity.type, entity.id),
        confidence = entity.confidence}
      if #output >= limit then break end
    end
  end
  return output
end
function C.itemList()
  local out = {}
  for _, entity in ipairs(data.entities or {}) do
    if entity.type == "item" then out[#out + 1] = entity end
  end
  return out
end
function C.recipeList()
  return data.recipes or {}
end
function C.zones()
  return data.zones or {}
end

-- Prefer client-provided textures, with a bundled Blizzard icon as an honest fallback.
function C.icon(kind, id)
  id = tonumber(id)
  if not id then return "Interface\\Icons\\INV_Misc_Book_09" end
  if kind == "item" and type(C_Item) == "table" then
    if type(C_Item.GetItemIconByID) == "function" then
      local icon = C_Item.GetItemIconByID(id)
      if icon then return icon end
    end
    if type(C_Item.GetItemInfo) == "function" then
      local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
      if icon then return icon end
    end
  elseif kind == "spell" and type(C_Spell) == "table" then
    if type(C_Spell.GetSpellTexture) == "function" then
      local icon = C_Spell.GetSpellTexture(id)
      if icon then return icon end
    end
    if type(C_Spell.GetSpellInfo) == "function" then
      local info = C_Spell.GetSpellInfo(id)
      if type(info) == "table" and info.iconID then return info.iconID end
    end
  end
  local entry = C.entity(kind, id)
  if kind == "item" then
    if entry and entry.category == "fish" then return "Interface\\Icons\\INV_Misc_Fish_02" end
    if entry and entry.category == "fishing_pole" then return "Interface\\Icons\\Trade_Fishing" end
    if entry and entry.category == "lure" then return "Interface\\Icons\\INV_Misc_Fishingpole_02" end
    return "Interface\\Icons\\INV_Misc_Bag_10"
  end
  return "Interface\\Icons\\INV_Misc_Book_09"
end
