-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure list/detail model. The UI never implies historical locations are currently active.
local _, ns = ...
ns.browser = {}
local B = ns.browser

local function entry(id, label, kind, confidence, extra)
  return {id = id, name = label, kind = kind, confidence = confidence, extra = extra}
end

local function include(rows, row, term)
  if term == "" or row.name:lower():find(term, 1, true)
    or tostring(row.id):lower():find(term, 1, true) then rows[#rows + 1] = row end
end

function B.list(category, term)
  term = type(term) == "string" and term:lower() or ""
  local rows = {}
  if category == "fish" or category == "gear" then
    local kinds = category == "fish" and {"fish"} or {"fishing_pole", "lure"}
    for _, kind in ipairs(kinds) do
      for _, rec in ipairs(ns.catalog.byCategory(kind, 100)) do
        include(rows, entry(rec.id, rec.name, kind, rec.confidence), term)
      end
    end
  elseif category == "recipes" then
    for _, r in ipairs(ns.catalog.recipeList()) do
      include(rows, entry(r.spellId, ns.catalog.name("spell", r.spellId),
        r.profession or "Cooking", r.confidence, r), term)
    end
  elseif category == "zones" then
    for _, z in ipairs(ns.catalog.zones()) do
      include(rows, entry(z.mapId, z.name, "zone", z.confidence), term)
    end
  elseif category == "schools" then
    for _, r in ipairs((ns.storage.db and ns.storage.db.schoolCandidates) or {}) do
      include(rows, entry(r.id, r.label, "school_candidate", "user_observation", r), term)
    end
  elseif category == "journal" then
    for id, r in pairs((ns.storage.db and ns.storage.db.catches) or {}) do
      include(rows, entry(id, r.name or id, "catch", "user_observation", r), term)
    end
  elseif category == "vendors" then
    for id, r in pairs((ns.storage.db and ns.storage.db.vendorObservations) or {}) do
      include(rows, entry(id, "NPC #" .. id, "merchant_observation",
        "user_observation", r), term)
    end
  end
  table.sort(rows, function(a, b)
    if a.name == b.name then return tostring(a.id) < tostring(b.id) end
    return a.name < b.name
  end)
  return rows
end

function B.details(row)
  if not row then return {"Select an entry for details."} end
  local out = {row.name .. " [" .. tostring(row.id) .. "]", "Source: " .. tostring(row.confidence)}
  if row.kind == "Cooking" or row.kind == "Fishing" then
    local plan = ns.kitchen.catalogPlan(row.id, 1)
    if plan then
      out[#out + 1] = "Minimum skill: " .. tostring(plan.minimumSkill)
      out[#out + 1] = "Creates: " .. plan.output
      for _, i in ipairs(plan.reagents) do
        out[#out + 1] = i.need .. " x " .. i.name .. " (missing: " .. i.missing .. ")"
      end
      out[#out + 1] = "Client data only; availability not verified."
    end
  elseif row.kind == "school_candidate" then
    out[#out + 1] = "Your position near a school, not its exact spawn."
    if row.extra then
      out[#out + 1] = string.format("Player coords: %.1f, %.1f", row.extra.x * 100, row.extra.y * 100)
    end
  elseif row.kind == "merchant_observation" then
    out[#out + 1] = "Items observed: " .. tostring(row.extra and #row.extra.items or 0)
    out[#out + 1] = "Not guaranteed current stock."
  elseif row.kind == "catch" then
    out[#out + 1] = "Recorded catches: " .. tostring(row.extra and row.extra.count or 0)
  else
    out[#out + 1] = "Historical/client reference; acquisition not confirmed."
  end
  return out
end
