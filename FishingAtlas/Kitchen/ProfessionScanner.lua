-- SPDX-License-Identifier: GPL-3.0-or-later
-- One read-only scanner for WoW Forever 1.60.1 and Classic trade skill APIs.
-- Modern profession identity is GetBaseProfessionInfo/GetChildProfessionInfo,
-- not the removed legacy GetTradeSkillLine return shape.
local _, ns = ...
ns.professionScanner = {}
local S = ns.professionScanner
local COOKING_ID, COOKING_ENUM = 185, 5
local LIMIT = 1200

local function apiCall(object, method, ...)
  if type(object) ~= "table" or type(object[method]) ~= "function" then
    return nil
  end
  local ok, a, b = pcall(object[method], ...)
  if ok then return a, b end
end

local function isCooking(info)
  if type(info) ~= "table" then return false end
  return tonumber(info.professionID) == COOKING_ID
    or tonumber(info.parentProfessionID) == COOKING_ID
    or tonumber(info.profession) == COOKING_ENUM
    or info.professionName == "Cooking"
    or info.parentProfessionName == "Cooking"
end

local function label(info)
  if type(info) ~= "table" then return "unknown profession" end
  return tostring(info.professionName or info.name
    or info.professionID or "unknown profession")
end

-- nil: no authoritative profession identity; true: Cooking; false: another
-- profession. Never let stale GetTradeSkillLine "UNKNOWN" override valid
-- modern GetBaseProfessionInfo/ChildProfessionInfo.
function S.detect()
  local api = C_TradeSkillUI
  if apiCall(api, "IsDataSourceChanging") == true then
    return nil, "Profession data is still changing; retry when Cooking loads"
  end
  for _, method in ipairs({"GetBaseProfessionInfo",
      "GetChildProfessionInfo"}) do
    local info = apiCall(api, method)
    if type(info) == "table" and
        (info.professionID or info.profession or info.professionName) then
      if isCooking(info) then return true, "Cooking" end
      return false, "Opened profession is " .. label(info) .. ", not Cooking"
    end
  end
  local modernLine, modernName = apiCall(api, "GetTradeSkillLine")
  if type(modernLine) == "table" then
    if isCooking(modernLine) then return true, "Cooking" end
    return false, "Opened profession is " .. label(modernLine) .. ", not Cooking"
  end
  if tonumber(modernLine) == COOKING_ID or modernName == "Cooking" then
    return true, "Cooking"
  end
  if type(GetTradeSkillLine) == "function" then
    local ok, name = pcall(GetTradeSkillLine)
    if ok and type(name) == "string" and name ~= "UNKNOWN"
        and name ~= "" then
      return name == "Cooking", name == "Cooking" and "Cooking"
        or "Opened profession is " .. name .. ", not Cooking"
    end
  end
  return nil, "Cooking profession identity unavailable; modern data not loaded"
end

local function catalogNames()
  local indexed, ambiguous = {}, {}
  local function put(id)
    local name = ns.catalog and ns.catalog.name
      and ns.catalog.name("spell", id) or nil
    if type(name) ~= "string" or name:find("^Spell #")
        or name:find("^Unresolved") then return end
    local key = name:lower()
    if indexed[key] and indexed[key] ~= id then
      ambiguous[key] = true
    else indexed[key] = id end
  end
  for _, row in ipairs(ns.catalog and ns.catalog.recipeList
      and ns.catalog.recipeList() or {}) do
    if row.profession == "Cooking" then put(row.spellId) end
  end
  for id, row in pairs((ns.data.gameFiles or {}).recipes or {}) do
    if row.profession == "Cooking" then put(id) end
  end
  for key in pairs(ambiguous) do indexed[key] = nil end
  return indexed
end

local function spellLinkId(link)
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("|Hspell:(%d+)"))
    or tonumber(link:match("|Henchant:(%d+)"))
end

local function outputId(link)
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("|Hitem:(%d+)"))
end

local function belongsToCooking(api, id)
  local info = apiCall(api, "GetProfessionInfoByRecipeID", id)
  if type(info) == "table" and
      (info.professionID or info.parentProfessionID
        or info.profession or info.professionName) then
    return isCooking(info)
  end
  local skillLine = apiCall(api, "GetTradeSkillLineForRecipe", id)
  if type(skillLine) == "number" then
    return skillLine == COOKING_ID
  end
  return true -- Current base profession is already verified as Cooking.
end

local function modern()
  local api = C_TradeSkillUI
  if type(api) ~= "table" or
      type(api.GetAllRecipeIDs) ~= "function"
      or type(api.GetRecipeInfo) ~= "function" then return nil end
  local ids = apiCall(api, "GetAllRecipeIDs")
  if type(ids) ~= "table" or #ids == 0 then
    return nil, "Cooking panel is open but recipe data is not loaded yet"
  end
  local entries, seen, learned = {}, {}, 0
  for index = 1, math.min(#ids, LIMIT) do
    local id = tonumber(ids[index])
    if id and id > 0 and not seen[id] then
      seen[id] = true
      local info = apiCall(api, "GetRecipeInfo", id)
      if type(info) == "table" and info.learned == true
          and info.isDummyRecipe ~= true and belongsToCooking(api, id) then
        learned = learned + 1
        local spellId = tonumber(info.recipeID) or id
        -- Forever's API documents recipe IDs as spell IDs. If an alternate
        -- ID is given, resolve the canonical ID only when the catalog proves it.
        if spellId ~= id and ns.catalog and ns.catalog.recipe
            and ns.catalog.recipe(id) and not ns.catalog.recipe(spellId) then
          spellId = id
        end
        local name = info.name
        if type(name) ~= "string" or name == "" then
          name = ns.catalog and ns.catalog.name
            and ns.catalog.name("spell", spellId) or nil
        end
        if type(name) == "string" and name ~= "" then
          local schematic = apiCall(api, "GetRecipeSchematic", id, false)
          local output = type(schematic) == "table"
            and tonumber(schematic.outputItemID) or nil
          entries[#entries + 1] = {spellId = spellId,
            name = name, outputItemId = output}
        end
      end
    end
  end
  return {entries = entries, learned = learned, inspected = #ids,
    backend = "Forever modern"}
end

local function legacy()
  if type(GetNumTradeSkills) ~= "function" or
      type(GetTradeSkillInfo) ~= "function" then return nil end
  local ok, count = pcall(GetNumTradeSkills)
  if not ok or type(count) ~= "number" or count <= 0 then
    return nil, "Cooking list is empty; wait for it to load"
  end
  local byName, entries, seen = catalogNames(), {}, {}
  for index = 1, math.min(count, LIMIT) do
    local good, name, skillType = pcall(GetTradeSkillInfo, index)
    if good and type(name) == "string" and name ~= ""
        and skillType ~= "header" and skillType ~= "subheader" then
      local spellId
      if type(GetTradeSkillRecipeLink) == "function" then
        local linkOk, link = pcall(GetTradeSkillRecipeLink, index)
        if linkOk then spellId = spellLinkId(link) end
      end
      spellId = spellId or byName[name:lower()]
      if spellId and not seen[spellId] then
        seen[spellId] = true
        local output
        if type(GetTradeSkillItemLink) == "function" then
          local linkOk, link = pcall(GetTradeSkillItemLink, index)
          if linkOk then output = outputId(link) end
        end
        entries[#entries + 1] = {spellId = spellId, name = name,
          outputItemId = output}
      end
    end
  end
  return {entries = entries, learned = #entries, inspected = count,
    backend = "legacy tradeskill"}
end

function S.readCooking()
  local detected, reason = S.detect()
  if not detected then return nil, reason end
  local data, problem = modern()
  if data then return data end
  local classic, oldProblem = legacy()
  if classic then return classic end
  return nil, problem or oldProblem
    or "Cooking is open, but this client provides no readable recipe list"
end
