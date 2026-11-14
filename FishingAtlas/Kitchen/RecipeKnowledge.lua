-- SPDX-License-Identifier: GPL-3.0-or-later
-- Per-character recipe knowledge: game APIs first, optional explicit override.
-- Values: known / unknown (not learned) / unchecked (API has no conclusion).
local _, ns = ...
ns.recipeKnowledge = {}
local K = ns.recipeKnowledge

local function characterKey()
  local name, realm
  if type(UnitFullName) == "function" then
    name, realm = UnitFullName("player")
  end
  if not name and type(UnitName) == "function" then name = UnitName("player") end
  if (not realm or realm == "") and type(GetRealmName) == "function" then
    realm = GetRealmName()
  end
  return tostring(realm or "Realm") .. "-" .. tostring(name or "Player")
end

local function overrides()
  local db = ns.storage and ns.storage.db
  if not db then return nil end
  db.recipeKnownByCharacter = db.recipeKnownByCharacter or {}
  local key = characterKey()
  db.recipeKnownByCharacter[key] = db.recipeKnownByCharacter[key] or {}
  return db.recipeKnownByCharacter[key]
end

function K.status(spellId)
  spellId = tonumber(spellId)
  if not spellId then return "unchecked" end
  local saved = overrides()
  if saved and saved[spellId] ~= nil then
    return saved[spellId] and "known" or "unknown", "manual_override"
  end
  if type(C_TradeSkillUI) == "table" and type(C_TradeSkillUI.GetRecipeInfo) == "function" then
    local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, spellId)
    if ok and type(info) == "table" and type(info.learned) == "boolean" then
      return info.learned and "known" or "unknown", "client_tradeskill"
    end
  end
  if type(IsSpellKnown) == "function" then
    local ok, known = pcall(IsSpellKnown, spellId)
    if ok and known == true then return "known", "client_spellbook" end
  end
  -- A missing spell in the spellbook is not proof the player can learn it.
  return "unchecked", "unverified"
end

function K.set(spellId, value)
  spellId = tonumber(spellId)
  if not spellId or spellId <= 0 then return false end
  local saved = overrides()
  if not saved then return false end
  if value == "known" then saved[spellId] = true
  elseif value == "unknown" then saved[spellId] = false
  elseif value == "unchecked" then saved[spellId] = nil
  else return false end
  return true
end

function K.cycle(spellId)
  local current = K.status(spellId)
  local nextState = current == "known" and "unknown"
    or current == "unknown" and "unchecked" or "known"
  if K.set(spellId, nextState) then return nextState end
  return nil
end
