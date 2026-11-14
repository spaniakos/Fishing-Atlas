-- SPDX-License-Identifier: GPL-3.0-or-later
-- Fishing Atlas recipe knowledge is character-specific and automatically
-- discovered from the live profession UI. Never equate an unloaded recipe API
-- with "not learned". Manual overrides are strictly a fallback.
local _, ns = ...
ns.recipeKnowledge = {}
local K = ns.recipeKnowledge
local scanner

local function characterKey()
  local name, realm
  if type(UnitFullName) == "function" then name, realm = UnitFullName("player") end
  if not name and type(UnitName) == "function" then name = UnitName("player") end
  if (not realm or realm == "") and type(GetRealmName) == "function" then
    realm = GetRealmName()
  end
  return tostring(realm or "Realm") .. "-" .. tostring(name or "Player")
end

local function characterStore(key)
  local db = ns.storage and ns.storage.db
  if not db then return nil end
  db[key] = db[key] or {}
  local char = characterKey()
  db[key][char] = db[key][char] or {}
  return db[key][char]
end

local function clientSpellKnown(spellId)
  if type(IsSpellKnown) == "function" then
    local ok, yes = pcall(IsSpellKnown, spellId)
    if ok and yes == true then return true end
  end
  if type(C_Spell) == "table" and type(C_Spell.IsSpellKnown) == "function" then
    local ok, yes = pcall(C_Spell.IsSpellKnown, spellId)
    if ok and yes == true then return true end
  end
  return false
end

-- The trade-skill recipeID is NOT necessarily the spell ID. Resolve recipe
-- identities against the atlas by verified names, and use product IDs when
-- duplicate names occur; never accidentally label a different recipe learned.
local function recipesByName()
  local map = {}
  local function put(id, recipe)
    local name = ns.catalog and ns.catalog.name and ns.catalog.name("spell", id)
    if type(name) ~= "string" or name == "" or name:find("Unresolved", 1, true)
        or name:find("Spell #", 1, true) then return end
    local key = name:lower()
    map[key] = map[key] or {}
    map[key][#map[key] + 1] = {id = tonumber(id), outputItemId = recipe.outputItemId}
  end
  for _, recipe in ipairs(ns.catalog and ns.catalog.recipeList() or {}) do
    put(recipe.spellId, recipe)
  end
  for id, recipe in pairs((ns.data.gameFiles or {}).recipes or {}) do
    if not (ns.catalog and ns.catalog.recipe and ns.catalog.recipe(id)) then
      put(id, recipe)
    end
  end
  return map
end

-- Query the exact spell IDs from our offline catalog. Unlike
-- GetFilteredRecipeIDs, this does not depend on a profession-panel filter.
-- Positive learned state is authoritative; a nil/false response alone is
-- not enough to infer a recipe is unlearned if its profession is not loaded.
function K.scanCatalog()
  local api = C_TradeSkillUI
  if type(api) ~= "table" or type(api.GetRecipeInfo) ~= "function" then return 0 end
  local auto = characterStore("recipeAutoByCharacter")
  if not auto then return 0 end
  local found, changed = {}, 0
  local function visit(id)
    id = tonumber(id)
    if not id or found[id] then return end
    found[id] = true
    local ok, info = pcall(api.GetRecipeInfo, id)
    if ok and type(info) == "table" and info.learned == true
        and not auto[id] then
      auto[id] = true
      changed = changed + 1
    end
  end
  for _, recipe in ipairs(ns.catalog and ns.catalog.recipeList() or {}) do
    visit(recipe.spellId)
  end
  for id in pairs((ns.data.gameFiles or {}).recipes or {}) do visit(id) end
  return changed
end

function K.scanModern()
  local api = C_TradeSkillUI
  if type(api) ~= "table" or type(api.GetRecipeInfo) ~= "function" then return 0 end
  local method = type(api.GetAllRecipeIDs) == "function" and api.GetAllRecipeIDs
    or type(api.GetFilteredRecipeIDs) == "function" and api.GetFilteredRecipeIDs
  if not method then return 0 end
  local ok, ids = pcall(method)
  if not ok or type(ids) ~= "table" or #ids == 0 then return 0 end
  local byName, auto = recipesByName(), characterStore("recipeAutoByCharacter")
  if not auto then return 0 end
  local changed = 0
  for _, id in ipairs(ids) do
    local succeeded, info = pcall(api.GetRecipeInfo, id)
    if succeeded and type(info) == "table" and type(info.name) == "string"
        and type(info.learned) == "boolean" and not info.isDummyRecipe then
      local matches = byName[info.name:lower()] or {}
      local spellId
      if #matches == 1 then spellId = matches[1].id
      elseif #matches > 1 and type(api.GetRecipeSchematic) == "function" then
        local schematicOK, schematic = pcall(api.GetRecipeSchematic, id, false)
        local output = schematicOK and type(schematic) == "table"
          and schematic.outputItemID or nil
        if output then
          for _, candidate in ipairs(matches) do
            if candidate.outputItemId == output then
              if spellId then spellId = nil; break end
              spellId = candidate.id
            end
          end
        end
      end
      if spellId and auto[spellId] ~= info.learned then
        auto[spellId] = info.learned
        changed = changed + 1
      end
    end
  end
  return changed
end

function K.status(spellId)
  spellId = tonumber(spellId)
  if not spellId then return "unknown", "unverified" end
  if clientSpellKnown(spellId) then return "known", "client_spellbook" end
  -- Forever's profession API accepts recipe spell IDs directly. Querying one
  -- ID also handles Cooking before the visible recipe list has been refreshed.
  if type(C_TradeSkillUI) == "table"
      and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, spellId)
    if ok and type(info) == "table" and info.learned == true then
      return "known", "client_recipe_info"
    end
  end
  local auto = characterStore("recipeAutoByCharacter")
  if auto and auto[spellId] ~= nil then
    return auto[spellId] and "known" or "unknown", "profession_scan"
  end
  local manual = characterStore("recipeKnownByCharacter")
  if manual and manual[spellId] ~= nil then
    return manual[spellId] and "known" or "unknown", "manual_override"
  end
  -- Unknown here is unverified, not proof that the character lacks the recipe.
  return "unknown", "not_yet_scanned"
end

function K.set(spellId, value)
  spellId = tonumber(spellId)
  if not spellId or spellId <= 0 then return false end
  local manual = characterStore("recipeKnownByCharacter")
  if not manual then return false end
  if value == "known" then manual[spellId] = true
  elseif value == "unknown" then manual[spellId] = false
  elseif value == "unchecked" then manual[spellId] = nil
  else return false end
  return true
end

function K.cycle(spellId)
  local current, source = K.status(spellId)
  if current == "known" and (source == "client_spellbook"
      or source == "client_recipe_info" or source == "profession_scan") then
    return "known" -- Never contradict authoritative client learning evidence.
  end
  local nextStatus = current == "known" and "unknown" or "known"
  return K.set(spellId, nextStatus) and nextStatus or nil
end

-- The legacy TradeSkill window supplies a *positive* list of learned skills,
-- even on clients that do not offer C_TradeSkillUI. Scan only the selected
-- profession, and never mark absent rows not-known (filters may be active).
-- Name matching is allowed only if the name uniquely maps to one known spell.
function K.scanOpenProfession()
  if type(GetNumTradeSkills) ~= "function"
      or type(GetTradeSkillInfo) ~= "function" then return 0 end
  local ok, count = pcall(GetNumTradeSkills)
  if not ok or type(count) ~= "number" or count <= 0 then return 0 end
  local auto = characterStore("recipeAutoByCharacter")
  if not auto then return 0 end
  local names, ambiguous = {}, {}
  local function register(id)
    local name = ns.catalog and ns.catalog.name and ns.catalog.name("spell", id)
    if type(name) ~= "string" or name == "" or name:find("Unresolved", 1, true)
        or name:find("Spell #", 1, true) then return end
    name = name:lower()
    if names[name] and names[name] ~= id then ambiguous[name] = true
    else names[name] = id end
  end
  for _, recipe in ipairs(ns.catalog and ns.catalog.recipeList() or {}) do
    register(recipe.spellId)
  end
  for id in pairs((ns.data.gameFiles or {}).recipes or {}) do register(id) end
  local added = 0
  for index = 1, count do
    local good, name, skillType = pcall(GetTradeSkillInfo, index)
    if good and type(name) == "string"
        and skillType ~= "header" and skillType ~= "subheader" then
      local spellId
      if type(GetTradeSkillRecipeLink) == "function" then
        local linkOk, link = pcall(GetTradeSkillRecipeLink, index)
        if linkOk and type(link) == "string" then
          spellId = tonumber(link:match("|Hspell:(%d+)"))
            or tonumber(link:match("|Henchant:(%d+)"))
        end
      end
      local key = name:lower()
      spellId = spellId or (not ambiguous[key] and names[key] or nil)
      if spellId and not auto[spellId] then
        auto[spellId] = true
        added = added + 1
      end
    end
  end
  return added
end

function K.refresh()
  local added = K.scanCatalog() + K.scanModern() + K.scanOpenProfession()
  if ns.ui and ns.ui.refresh then ns.ui.refresh(false) end
  return added
end

function K.start()
  if scanner or type(CreateFrame) ~= "function" then return end
  scanner = CreateFrame("Frame")
  K.supportedEvents, K.unsupportedEvents = {}, {}
  -- WoW Forever does not necessarily expose retail/Classic profession events.
  -- RegisterEvent throws for unknown events. Never abort ADDON_LOADED because
  -- an optional profession event is unavailable on this client build.
  for _, event in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE",
      "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED",
      "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB"}) do
    local ok = pcall(scanner.RegisterEvent, scanner, event)
    if ok then
      K.supportedEvents[#K.supportedEvents + 1] = event
    else
      K.unsupportedEvents[#K.unsupportedEvents + 1] = event
    end
  end
  scanner:SetScript("OnEvent", function() K.refresh() end)
  return true
end
