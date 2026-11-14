-- SPDX-License-Identifier: GPL-3.0-or-later
-- Personal recipe discoveries. Manual additions are NOT proof of learning.
-- Only a positive Cooking profession window scan may mark a recipe learned.
local _, ns = ...
ns.recipeDiscovery = {}
local D = ns.recipeDiscovery
local MAX_PERSONAL = 400

local function store()
  local db = ns.storage and ns.storage.db
  if not db then return nil end
  db.discoveredRecipes = db.discoveredRecipes or {}
  return db.discoveredRecipes
end

local function idFrom(value)
  if type(value) == "number" then value = tostring(value) end
  if type(value) ~= "string" then return nil end
  local id = value:match("|Hspell:(%d+)") or value:match("|Henchant:(%d+)")
    or value:match("^%s*(%d+)%s*$")
  id = tonumber(id)
  if id and id > 0 and id <= 9999999 and id == math.floor(id) then
    return id
  end
end

function D.get(id)
  return (store() or {})[tonumber(id)]
end

function D.list()
  local out = {}
  for _, rec in pairs(store() or {}) do out[#out + 1] = rec end
  return out
end

function D.add(input, name, evidence, outputItemID)
  local id = idFrom(input)
  if not id then return nil, "Enter a valid Cooking spell ID or spell link" end
  local records = store()
  if not records then return nil, "SavedVariables are not initialized" end
  local known = records[id]
  if not known and not (ns.catalog and ns.catalog.recipe and
      ns.catalog.recipe(id)) then
    local n = 0
    for _ in pairs(records) do n = n + 1 end
    if n >= MAX_PERSONAL then return nil, "Personal recipe limit reached" end
  end
  local resolved = ns.catalog and ns.catalog.name and
    ns.catalog.name("spell", id) or nil
  local label = name or resolved
  if type(label) ~= "string" or label == "" then
    label = "Spell #" .. id
  end
  if ns.util and ns.util.safeText then label = ns.util.safeText(label) end
  local scanned = evidence == "client_profession"
  local rec = known or {id = id, profession = "Cooking"}
  if not known or scanned or rec.name:find("^Spell #") then
    rec.name = label
  end
  if scanned then
    rec.source = "client_profession"
    if type(outputItemID) == "number" and outputItemID > 0 then
      rec.outputItemId = outputItemID
    end
    if ns.recipeKnowledge and ns.recipeKnowledge.observeLearned then
      ns.recipeKnowledge.observeLearned(id)
    end
  else
    rec.source = rec.source or "personal_reference"
  end
  records[id] = rec
  return rec, not known
end

local function cookingOpen()
  if type(GetTradeSkillLine) == "function" then
    local ok, name = pcall(GetTradeSkillLine)
    if ok then return name == "Cooking" end
  end
  if type(C_TradeSkillUI) == "table" and
      type(C_TradeSkillUI.GetTradeSkillLine) == "function" then
    local ok, info = pcall(C_TradeSkillUI.GetTradeSkillLine)
    if ok and type(info) == "table" then
      return info.name == "Cooking" or info.professionName == "Cooking"
    end
  end
  return false
end

local function outputFromLink(link)
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("|Hitem:(%d+)"))
end

local function legacyScan()
  if type(GetNumTradeSkills) ~= "function" or
      type(GetTradeSkillInfo) ~= "function" then return 0 end
  local ok, count = pcall(GetNumTradeSkills)
  if not ok or type(count) ~= "number" then return 0 end
  local added = 0
  for index = 1, math.min(count, 600) do
    local infoOK, name, difficulty = pcall(GetTradeSkillInfo, index)
    if infoOK and type(name) == "string" and name ~= "" and
        difficulty ~= "header" and difficulty ~= "subheader" then
      local spellID
      if type(GetTradeSkillRecipeLink) == "function" then
        local linkOK, link = pcall(GetTradeSkillRecipeLink, index)
        if linkOK then spellID = idFrom(link) end
      end
      -- A legacy recipe without a stable spell ID is deliberately not
      -- invented or matched by a possibly ambiguous display name.
      if spellID then
        local outputID
        if type(GetTradeSkillItemLink) == "function" then
          local linkOK, link = pcall(GetTradeSkillItemLink, index)
          if linkOK then outputID = outputFromLink(link) end
        end
        local _, created = D.add(spellID, name, "client_profession", outputID)
        if created then added = added + 1 end
      end
    end
  end
  return added
end

local function modernScan()
  local api = C_TradeSkillUI
  if type(api) ~= "table" or
      type(api.GetAllRecipeIDs) ~= "function" or
      type(api.GetRecipeInfo) ~= "function" then return 0 end
  local ok, ids = pcall(api.GetAllRecipeIDs)
  if not ok or type(ids) ~= "table" then return 0 end
  local added = 0
  for index = 1, math.min(#ids, 600) do
    local id = tonumber(ids[index])
    local valid, rec = pcall(api.GetRecipeInfo, id)
    if valid and type(rec) == "table" and rec.learned == true
        and type(rec.name) == "string" and not rec.isDummyRecipe then
      -- Modern recipe IDs can differ from spell IDs. Require a catalog ID,
      -- or positive identity with a matching client spell tooltip.
      local spellName = ns.catalog and ns.catalog.name and
        ns.catalog.name("spell", id) or ""
      if ns.catalog and ns.catalog.recipe and ns.catalog.recipe(id)
          or type(spellName) == "string"
          and spellName:lower() == rec.name:lower() then
        local _, created = D.add(id, rec.name, "client_profession")
        if created then added = added + 1 end
      end
    end
  end
  return added
end

function D.scan()
  if not cookingOpen() then
    return nil, "Open the Cooking profession window, then scan"
  end
  return legacyScan() + modernScan(), "Scanned open Cooking profession"
end
