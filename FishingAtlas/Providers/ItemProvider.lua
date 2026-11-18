-- SPDX-License-Identifier: GPL-3.0-or-later
-- Optional LibItemDB adapter. Never infer live availability from an offline ID.
local _, ns = ...
ns.itemProvider = {}
local P = ns.itemProvider

local function library()
  if not LibStub then return nil, "missing" end
  local ok, lib = pcall(LibStub, "LibItemDB-1.0", true)
  if not ok or type(lib) ~= "table" then return nil, "missing" end
  if type(lib.IsReady) ~= "function" then return nil, "unsupported" end
  local ready, value = pcall(lib.IsReady, lib)
  if not ready or value ~= true then return nil, "not_ready" end
  -- Only accept explicit Forever designation: Vanilla IDs also resolve, but
  -- generic Vanilla data is NOT verified Forever evidence.
  if type(lib.GetGameVersion) ~= "function" then return nil, "version_unknown" end
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
  local ok, value = pcall(lib[method], lib, tonumber(id))
  if not ok then return nil end
  if type(issecretvalue) == "function" then
    local safe, secret = pcall(issecretvalue, value)
    if not safe or secret then return nil end
  end
  return value
end

function P.name(id)
  local value = request("GetName", id)
  if type(value) == "string" and value ~= "" then return value, "libitemdb_forever" end
end

function P.link(id)
  local value = request("GetLink", id)
  if type(value) == "string" and value:find("|Hitem:", 1, true) then
    return value, "libitemdb_forever"
  end
end

-- A library item's presence is only a description of the library's snapshot.
-- The addon never uses GetSources as verification of an active Forever seller.
