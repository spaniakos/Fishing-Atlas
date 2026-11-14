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

local function clientRecipe(spellId)
  if type(C_TradeSkillUI) == "table"
      and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, spellId)
    if ok and type(info) == "table" and type(info.learned) == "boolean" then
      return info.learned and "known" or "unknown", "client_tradeskill"
    end
  end
  if type(IsSpellKnown) == "function" then
    local ok, yes = pcall(IsSpellKnown, spellId)
    if ok and yes == true then return "known", "client_spellbook" end
  end
  if type(C_Spell) == "table" and type(C_Spell.IsSpellKnown) == "function" then
    local ok, yes = pcall(C_Spell.IsSpellKnown, spellId)
    if ok and yes == true then return "known", "client_spellbook" end
  end
end

function K.status(spellId)
  spellId = tonumber(spellId)
  if not spellId then return "unchecked", "unverified" end
  local status, reason = clientRecipe(spellId)
  if status then return status, reason end
  local auto = characterStore("recipeAutoByCharacter")
  if auto and auto[spellId] == true then return "known", "profession_scan" end
  local manual = characterStore("recipeKnownByCharacter")
  if manual and manual[spellId] ~= nil then
    return manual[spellId] and "known" or "unknown", "manual_override"
  end
  return "unchecked", "not_yet_scanned"
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
  local current = K.status(spellId)
  local new = current == "known" and "unknown"
    or current == "unknown" and "unchecked" or "known"
  return K.set(spellId, new) and new or nil
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
  local added = K.scanOpenProfession()
  if ns.ui and ns.ui.refresh then ns.ui.refresh(false) end
  return added
end

function K.start()
  if scanner or type(CreateFrame) ~= "function" then return end
  scanner = CreateFrame("Frame")
  for _, event in ipairs({"TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE",
      "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB"}) do
    scanner:RegisterEvent(event)
  end
  scanner:SetScript("OnEvent", function() K.refresh() end)
end
