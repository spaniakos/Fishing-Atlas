-- SPDX-License-Identifier: GPL-3.0-or-later
-- Optional LibProfessionDB adapter; never equate recipe presence with learning.
local _, ns = ...
ns.professionProvider = {}
local P = ns.professionProvider

local function library()
  if not LibStub then return nil, "missing" end
  local ok, lib = pcall(LibStub, "LibProfessionDB-1.0", true)
  if not ok or type(lib) ~= "table" then return nil, "missing" end
  if type(lib.IsReady) ~= "function" or type(lib.GetGameVersion) ~= "function" then
    return nil, "unsupported"
  end
  local ready, yes = pcall(lib.IsReady, lib)
  if not ready or yes ~= true then return nil, "not_ready" end
  local versionOK, version = pcall(lib.GetGameVersion, lib)
  if not versionOK or version ~= "Forever" then return nil, "wrong_game" end
  return lib, "ready"
end

function P.status()
  local lib, reason = library()
  return lib ~= nil, reason
end

local function request(method, id)
  local lib = library()
  if not lib or type(lib[method]) ~= "function" then return nil end
  local ok, value, additional = pcall(lib[method], lib, tonumber(id))
  if not ok then return nil end
  if type(issecretvalue) == "function" then
    local safe, secret = pcall(issecretvalue, value)
    if not safe or secret then return nil end
  end
  return value, additional
end

function P.requirement(spellID)
  local skill = request("GetRequiredSkill", spellID)
  if type(skill) ~= "number" or skill < 1 then return nil end
  local borrowed = request("IsBorrowed", spellID)
  return skill, borrowed == true and "borrowed_classic_reference"
    or "libprofessiondb_forever"
end

function P.teachingItem(spellID)
  local id, isBook = request("GetRecipeItem", spellID)
  if type(id) == "table" then id = id.itemId or id.itemID end
  if type(id) == "number" and id > 0 and not isBook then
    return id, "libprofessiondb_forever"
  end
end

function P.reagents(spellID)
  local value = request("GetReagents", spellID)
  if type(value) ~= "table" then return nil end
  -- Keep library data separate from canonical recipe graph; do not silently
  -- change recipe IDs, counts, or acquisition provenance.
  return value, "libprofessiondb_forever"
end
