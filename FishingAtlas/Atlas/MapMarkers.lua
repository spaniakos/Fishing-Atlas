-- SPDX-License-Identifier: GPL-3.0-or-later
-- Single marker model for the explorer preview and the native World Map.
-- Active/Probable governs ONLY school evidence; vendors and saved spots remain.
local _, ns = ...
ns.mapMarkers = {}
local M = ns.mapMarkers
local schoolKinds = {
  school = true, school_live_nearby = true, school_candidate = true,
  school_guide = true, school_classic_reference = true, observed_school = true
}

function M.isSchool(point)
  return point and schoolKinds[point.kind] == true
end

local function mode()
  return ns.storage and ns.storage.db and ns.storage.db.settings
    and ns.storage.db.settings.schoolMapMode or "active"
end

local function valid(point, mapID)
  return type(point) == "table" and point.mapID == mapID
    and ns.util.validCoordinate(point.x) and ns.util.validCoordinate(point.y)
end

-- A school reference can be well sourced without being an active spawn.
function M.collect(item, mapID, selected)
  if type(mapID) ~= "number" then return {} end
  local output, seen = {}, {}
  local schoolMode = mode()
  local function add(point, highlight)
    if not valid(point, mapID) then return end
    if not highlight and M.isSchool(point) and schoolMode == "active"
        and point.kind ~= "school_live_nearby" then return end
    local label = tostring(point.label or point.name or "Fishing Atlas position")
    local source = tostring(point.source or "unspecified_source")
    local kind = tostring(point.kind or "position")
    local key = string.format("%s:%s:%.5f:%.5f:%s",
      kind, label, point.x, point.y, source)
    local existing = seen[key]
    if existing then
      if highlight then existing.isSelected = true end
      return
    end
    local rec = {mapID = mapID, x = point.x, y = point.y,
      kind = kind, label = label, source = source,
      isSelected = highlight or point.isSelected or false,
      verifiedSpawn = point.verifiedSpawn == true, near = point.near == true,
      confidence = point.confidence or source}
    output[#output + 1] = rec
    seen[key] = rec
  end

  -- The explicitly clicked detail must win pin priority, even on a busy map.
  if selected then
    local chosen = {mapID = selected.mapID, x = selected.x, y = selected.y,
      kind = selected.kind or "selected_position",
      label = selected.label or selected.title or "Selected location",
      source = selected.source or "selected_record"}
    add(chosen, true)
  end

  if item and ns.viewModel and ns.viewModel.mapPoints then
    for _, point in ipairs(ns.viewModel.mapPoints(item) or {}) do
      add(point, false)
    end
  end

  -- Saved personal spots are useful in both school-visibility modes.
  if ns.storage and type(ns.storage.inZone) == "function" then
    for _, point in ipairs(ns.storage.inZone(mapID)) do
      add({mapID = mapID, x = point.x, y = point.y, kind = "player_position",
        label = point.label or "Saved fishing place",
        source = point.source or "your_saved_position"}, false)
    end
  end

  if schoolMode == "active" then
    if ns.liveSchools then
      local schoolName = item and item.kind == "school_type" and item.name or nil
      for _, point in ipairs(ns.liveSchools.inZone(mapID, schoolName)) do
        add(point, false)
      end
    end
  else
    local schoolName = item and item.kind == "school_type" and item.name or nil
    if ns.schools and type(ns.schools.inZone) == "function" then
      for _, point in ipairs(ns.schools.inZone(mapID)) do
        if not schoolName or schoolName == point.label then
          add({mapID = mapID, x = point.x, y = point.y,
            label = point.label, kind = "school_candidate",
            source = "your_school_proximity"}, false)
        end
      end
    end
    for _, catalog in ipairs({ns.data and ns.data.classicSchoolLocations or {},
        ns.data and ns.data.referenceSchoolLocations or {}}) do
      for name, locations in pairs(catalog) do
        if not schoolName or schoolName == name then
          for _, loc in ipairs(locations) do
            add({mapID = loc.mapID, x = loc.x, y = loc.y, label = name,
              kind = "school_classic_reference",
              source = loc.source or "classic_reference"}, false)
          end
        end
      end
    end
    if ns.sources and type(ns.sources.schools) == "function" then
      for _, school in ipairs(ns.sources.schools()) do
        if not schoolName or schoolName == school.name then
          for _, loc in ipairs(school.spots or {}) do
            if (loc.installs or 0) >= 3 then
              add({mapID = loc.mapID, x = loc.x, y = loc.y, label = school.name,
                kind = "observed_school", source = "observed_source",
                verifiedSpawn = false}, false)
            end
          end
        end
      end
    end
  end
  table.sort(output, function(a, b)
    if a.isSelected ~= b.isSelected then return a.isSelected end
    local ak, bk = a.kind .. ":" .. a.label .. ":" .. a.source,
      b.kind .. ":" .. b.label .. ":" .. b.source
    if ak ~= bk then return ak < bk end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  return output
end

function M.signature(points)
  local parts = {}
  for _, point in ipairs(points or {}) do
    parts[#parts + 1] = string.format("%s|%s|%s|%.6f|%.6f|%s",
      point.kind or "", point.label or "", point.source or "",
      point.x, point.y, point.isSelected and "selected" or "ordinary")
  end
  return table.concat(parts, ";")
end
