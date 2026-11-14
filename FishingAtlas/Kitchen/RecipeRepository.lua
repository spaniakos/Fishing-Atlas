-- SPDX-License-Identifier: GPL-3.0-or-later
-- Recipes v2, phase 1: one read-only index with typed spell/item identities.
-- Per-character learning, account collection and user observations stay separate.
local _, ns = ...
ns.recipeRepository = {}
local R = ns.recipeRepository
local graph = ns.data.recipeIndex or {}
local bySpell = {}

for _, entry in ipairs(graph.records or {}) do
  assert(type(entry.spellId) == "number" and entry.spellId > 0
    and type(entry.professionId) == "number"
    and bySpell[entry.spellId] == nil, "Duplicate or invalid recipe index")
  bySpell[entry.spellId] = entry
end

local function personal(id)
  if not ns.recipeDiscovery or type(ns.recipeDiscovery.get) ~= "function" then
    return nil
  end
  local record = ns.recipeDiscovery.get(id)
  if type(record) ~= "table" or record.profession ~= "Cooking" then return nil end
  return {spellId = id, professionId = 185, profession = "Cooking",
    clientRecipeId = nil, name = record.name or ("Spell #" .. id),
    output = record.outputItemId and {itemId = record.outputItemId,
      quantity = 1} or nil,
    reagents = {}, skills = {learn = nil, yellow = nil, grey = nil},
    teachingItems = {}, acquisitions = {}, confidence = "personal_reference",
    personal = true}
end

function R.get(id)
  id = tonumber(id)
  if not id or id <= 0 then return nil end
  return bySpell[id] or personal(id)
end

function R.list()
  local result, seen = {}, {}
  for _, entry in ipairs(graph.records or {}) do
    result[#result + 1] = entry
    seen[entry.spellId] = true
  end
  if ns.recipeDiscovery and ns.recipeDiscovery.list then
    for _, rec in ipairs(ns.recipeDiscovery.list() or {}) do
      if type(rec) == "table" and type(rec.id) == "number"
          and not seen[rec.id] then
        local entry = personal(rec.id)
        if entry then
          result[#result + 1] = entry
          seen[rec.id] = true
        end
      end
    end
  end
  table.sort(result, function(a, b) return a.spellId < b.spellId end)
  return result
end

function R.sources(spellId)
  local entry = R.get(spellId)
  return entry and entry.acquisitions or {}
end

function R.learnRank(spellId)
  local entry = R.get(spellId)
  return entry and entry.skills and entry.skills.learn or nil
end

function R.mapPoints(spellId)
  local points = {}
  for _, source in ipairs(R.sources(spellId)) do
    if type(source.mapID) == "number"
        and ns.util.validCoordinate(source.x)
        and ns.util.validCoordinate(source.y) then
      local vendor = source.relation == "vendor_sells_item"
      points[#points + 1] = {mapID = source.mapID, x = source.x,
        y = source.y, kind = vendor and "vendor" or "npc",
        label = source.name or "Cooking source",
        source = source.source .. (source.sourceBuild
          and ("_" .. source.sourceBuild) or "")}
    end
  end
  return points
end

function R.coverage()
  return graph.coverage or {total = #R.list()}
end

function R.conflicts()
  return graph.conflicts or {}
end
