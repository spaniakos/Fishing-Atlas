-- SPDX-License-Identifier: GPL-3.0-or-later
-- Fishing-only scope. The upstream corpus covers Azeroth, not just fishing.
-- Root entities: observed fishing catches/pools, fishing equipment, and fish
-- references. Cooking products and ingredients are linked only when a recipe
-- consumes a fishing-root item. Do NOT infer relevance from every NPC or drop.
local _, ns = ...
ns.fishingScope = {}
local S = ns.fishingScope
local cached

local function add(set, id)
  id = tonumber(id)
  if id and id > 0 then set[id] = true end
end

local function recipes()
  local out = {}
  for _, recipe in ipairs(ns.catalog.recipeList()) do
    out[#out + 1] = recipe
  end
  for id, recipe in pairs((ns.data.gameFiles or {}).recipes or {}) do
    if not ns.catalog.recipe(id) then out[#out + 1] = recipe end
  end
  return out
end

local function ingredients(recipe)
  local out = {}
  for _, rec in ipairs(recipe.ingredients or recipe.reagents or {}) do
    local id = rec.itemId
    if id then out[#out + 1] = id end
  end
  return out
end

-- Raw Spinefin Halibut (8959) is a verified client Cooking ingredient for
-- Spinefin Halibut (8957). It is also vendor/creature loot on Forever.
-- Fishing relevance does NOT imply it can actually be caught with a fishing cast.
local cookingRelated = {[8959] = true}

function S.build()
  local roots, items, vendors, mobs, caught = {}, {}, {}, {}, {}
  local observed = ns.data.everloot or {}
  for _, ent in ipairs(ns.catalog.itemList()) do
    if ent.category == "fish" then
      add(roots, ent.id)
      add(caught, ent.id)
    elseif ent.category == "fishing_pole" or ent.category == "lure" then
      add(roots, ent.id)
    end
  end
  for _, fish in pairs(ns.data.referenceZoneFish or {}) do
    for _, record in ipairs(fish) do
      local id = type(record) == "table" and record.id or record
      add(roots, id)
      add(caught, id)
    end
  end
  for id in pairs(observed.fishing or {}) do
    add(roots, id)
    add(caught, id)
  end
  for id in pairs(observed.poolItems or {}) do
    add(roots, id)
    add(caught, id)
  end
  for id, record in pairs((ns.storage.db and ns.storage.db.catches) or {}) do
    local catchID = type(record) == "table" and record.id or id
    add(roots, catchID)
    add(caught, catchID)
  end
  -- Explicit fishing supplies from the indexed reference sources.
  for _, vendor in ipairs(ns.data.referenceVendors or {}) do
    for _, id in ipairs(vendor.items or {}) do
      if ns.catalog.entity("item", id) then
        local entry = ns.catalog.entity("item", id)
        if entry.category == "fishing_pole" or entry.category == "lure" then
          add(roots, id)
        end
      end
    end
  end
  for id in pairs(roots) do items[id] = true end
  for id in pairs(cookingRelated) do items[id] = true end
  -- Only fish-dependent Cooking recipes expand our inventory universe.
  for _, recipe in ipairs(recipes()) do
    local ing = ingredients(recipe)
    local linked = false
    for _, id in ipairs(ing) do
      if roots[id] or cookingRelated[id] then linked = true; break end
    end
    if linked then
      add(items, recipe.outputItemId)
      for _, id in ipairs(ing) do add(items, id) end
      add(items, recipe.recipeItemId)
    end
  end
  -- Fishing equipment can be sold by general merchants. Those sellers are
  -- relevant, but the rest of a general merchant's stock is not.
  for _, reference in ipairs(ns.data.referenceVendors or {}) do
    local relevant = reference.trainer == true
      or tostring(reference.title or ""):lower():find("fish", 1, true) ~= nil
    for _, id in ipairs(reference.items or {}) do
      if items[id] then relevant = true; break end
    end
    if relevant then add(vendors, reference.id) end
  end
  for itemId in pairs(items) do
    for _, rec in ipairs((observed.vendorItems or {})[itemId] or {}) do
      add(vendors, rec.npcId)
    end
    for _, rec in ipairs((observed.drops or {})[itemId] or {}) do
      add(mobs, rec.npcId)
    end
  end
  for id, entry in pairs((ns.storage.db and ns.storage.db.vendorObservations) or {}) do
    for _, good in ipairs(entry.items or {}) do
      if items[good] then add(vendors, id); break end
    end
  end
  cached = {items = items, roots = roots, caught = caught,
    vendors = vendors, mobs = mobs}
  return cached
end

function S.data() return cached or S.build() end
function S.item(id) return S.data().items[tonumber(id)] == true end
function S.caught(id) return S.data().caught[tonumber(id)] == true end
function S.vendor(id) return S.data().vendors[tonumber(id)] == true end
function S.mob(id) return S.data().mobs[tonumber(id)] == true end
function S.isFishingRoot(id) return S.data().roots[tonumber(id)] == true end
function S.invalidate() cached = nil end
