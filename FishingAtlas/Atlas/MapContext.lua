-- SPDX-License-Identifier: GPL-3.0-or-later
-- Geographic context ONLY when Forever provides a reliable parent rectangle.
-- This is a real client-art underlay, not a fabricated map or scaled sibling.
local _, ns = ...
ns.mapContext = {}
local M = ns.mapContext

function M.geometry(mapID)
  local api = C_Map
  if type(api) ~= "table" or type(api.GetMapInfo) ~= "function"
      or type(api.GetMapRectOnMap) ~= "function" then
    return nil, "parent map geometry API unavailable"
  end
  if type(api.IsCityMap) == "function" then
    local ok, city = pcall(api.IsCityMap, mapID)
    if ok and city then return nil, "city map uses separate art" end
  end
  local ok, info = pcall(api.GetMapInfo, mapID)
  local parent = ok and type(info) == "table" and tonumber(info.parentMapID) or nil
  if not parent or parent <= 0 or parent == mapID then
    return nil, "no usable parent map"
  end
  local good, x0, x1, y0, y1 = pcall(api.GetMapRectOnMap, mapID, parent)
  if not good or type(x0) ~= "number" or type(x1) ~= "number"
      or type(y0) ~= "number" or type(y1) ~= "number" then
    return nil, "parent rectangle unavailable"
  end
  local rw, rh = x1 - x0, y1 - y0
  -- Extreme scale, missing/negative or out-of-parent coordinates are unsafe.
  -- Each transform is confined to the same parent map ID, never siblings.
  if x0 ~= x0 or x1 ~= x1 or y0 ~= y0 or y1 ~= y1
      or x0 < 0 or y0 < 0 or x1 > 1 or y1 > 1
      or rw < 0.045 or rh < 0.045 or rw > 0.96 or rh > 0.96 then
    return nil, "parent rectangle outside safe bounds"
  end
  return {mapID = mapID, parentID = parent,
    minX = x0, maxX = x1, minY = y0, maxY = y1,
    spanX = rw, spanY = rh}
end

-- Project parent art onto a child map rectangle and clip every tile to view.
-- Clipped texture UVs retain the original parent FileDataID orientation.
function M.project(tiles, pox, poy, parentW, parentH, geometry, ox, oy, w, h)
  local out = {}
  if not geometry or not parentW or not parentH
      or parentW <= 0 or parentH <= 0 or w <= 0 or h <= 0 then return out end
  for _, tile in ipairs(tiles or {}) do
    local u0 = ((tile.x - pox) / parentW - geometry.minX) / geometry.spanX
    local v0 = ((tile.y - poy) / parentH - geometry.minY) / geometry.spanY
    local u1 = (((tile.x - pox) + tile.w) / parentW - geometry.minX)
      / geometry.spanX
    local v1 = (((tile.y - poy) + tile.h) / parentH - geometry.minY)
      / geometry.spanY
    local left, top = math.max(0, u0), math.max(0, v0)
    local right, bottom = math.min(1, u1), math.min(1, v1)
    if right > left and bottom > top and u1 > u0 and v1 > v0 then
      out[#out + 1] = {texture = tile.texture,
        x = ox + left * w, y = oy + top * h,
        w = (right - left) * w, h = (bottom - top) * h,
        u0 = (left - u0) / (u1 - u0) * (tile.u or 1),
        v0 = (top - v0) / (v1 - v0) * (tile.v or 1),
        u1 = (right - u0) / (u1 - u0) * (tile.u or 1),
        v1 = (bottom - v0) / (v1 - v0) * (tile.v or 1)}
    end
  end
  return out
end

function M.tiles(mapID, ox, oy, w, h)
  local settings = ns.storage and ns.storage.db and ns.storage.db.settings
  if settings and settings.mapContext == false then
    return {}, "disabled in preferences"
  end
  local rect, reason = M.geometry(mapID)
  if not rect then return {}, reason end
  if not ns.zoneMap or type(ns.zoneMap.artForMap) ~= "function" then
    return {}, "parent art renderer unavailable"
  end
  local parent, px, py, pw, ph, meta =
    ns.zoneMap.artForMap(rect.parentID, 1024, 1024)
  if not meta or not meta.expected or meta.expected == 0
      or (meta.coverage or 0) < 0.9 or #parent > 160 then
    return {}, "parent map artwork incomplete"
  end
  local tiles = M.project(parent, px, py, pw, ph, rect, ox, oy, w, h)
  if #tiles == 0 then return {}, "parent artwork does not intersect zone" end
  return tiles, string.format("parent %d | rect %.3f,%.3f to %.3f,%.3f",
    rect.parentID, rect.minX, rect.minY, rect.maxX, rect.maxY)
end

function M.describe(mapID)
  local rect, reason = M.geometry(mapID)
  if not rect then return reason end
  return string.format("parent %d | rect %.3f,%.3f to %.3f,%.3f",
    rect.parentID, rect.minX, rect.minY, rect.maxX, rect.maxY)
end
