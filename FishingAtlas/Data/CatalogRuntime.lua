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


-- Resolve optional, independently installed libraries without making them required.
-- A library may have no Forever dataset yet, be loading, or throw on a stale API.
local function optionalLibrary(name)
  if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return nil end
  local ok, lib = pcall(LibStub, name, true)
  if not ok or type(lib) ~= "table" then return nil end
  if type(lib.IsReady) == "function" then
    local good, ready = pcall(lib.IsReady, lib)
    if not good or ready ~= true then return nil end
  end
  return lib
end

function C.externalLibraryAvailable(name)
  if name ~= "LibItemDB-1.0" and name ~= "LibProfessionDB-1.0" then return false end
  return optionalLibrary(name) ~= nil
end

function C.itemLink(id)
  id = tonumber(id)
  if not id then return nil end
  local lib = optionalLibrary("LibItemDB-1.0")
  if lib and type(lib.GetLink) == "function" then
    local ok, link = pcall(lib.GetLink, lib, id)
    if ok and type(link) == "string" and link ~= "" then return link end
  end
  return nil
end

-- A library recipe can supplement our canonical recipe, never silently overwrite
-- its client-extracted fields or claim a borrowed Vanilla source is live verified.
function C.professionRecord(spellID)
  local own = C.recipe(spellID)
  local id = tonumber(spellID)
  local skillLineID = own and tonumber(own.professionId)
  if not id or not skillLineID then return nil end
  local lib = optionalLibrary("LibProfessionDB-1.0")
  if not lib or type(lib.GetRecipe) ~= "function" then return nil end
  local ok, record = pcall(lib.GetRecipe, lib, skillLineID, id)
  if not ok or type(record) ~= "table" then return nil end
  local meta = {source = "libprofessiondb_offline_reference", verifiedInForever = false}
  if type(lib.GetBorrowed) == "function" then
    local good, borrowed = pcall(lib.GetBorrowed, lib, id)
    if good and type(borrowed) == "table" then meta.borrowed = borrowed end
  end
  return record, meta
end

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
  if kind == "item" then
    local lib = optionalLibrary("LibItemDB-1.0")
    if lib and type(lib.GetName) == "function" then
      local ok, resolved = pcall(lib.GetName, lib, id)
      if ok and type(resolved) == "string" and resolved ~= "" then
        return resolved, false -- offline record, not a live client verification
      end
    end
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
function C.recipeList()
  return data.recipes or {}
end
function C.zones()
  return data.zones or {}
end

-- Prefer client-provided textures, with a bundled Blizzard icon as an honest fallback.
function C.icon(kind, id)
  id = tonumber(id)
  if not id then return "Interface\\Icons\\INV_Misc_QuestionMark" end
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
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
