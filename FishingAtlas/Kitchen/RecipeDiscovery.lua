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
  if known and type(known) ~= "table" then known = nil end
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
  if not known or scanned or type(rec.name) ~= "string"
      or rec.name:find("^Spell #") then
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

-- The profession reader is shared with character knowledge. Do not gate
-- this on legacy GetTradeSkillLine(), which Forever can leave unavailable.
function D.scan()
  if not ns.professionScanner then
    return nil, "Cooking scanner is not loaded"
  end
  local result, reason = ns.professionScanner.readCooking()
  if not result then return nil, reason end
  local added, seen = 0, {}
  for _, entry in ipairs(result.entries) do
    if not seen[entry.spellId] then
      seen[entry.spellId] = true
      local rec, created = D.add(entry.spellId, entry.name,
        "client_profession", entry.outputItemId)
      if rec and created then added = added + 1 end
    end
  end
  local message = string.format("Cooking: %d learned recipes recognized " ..
    "from %d rows (%s)", #result.entries, result.inspected,
    result.backend)
  return added, message
end
