-- SPDX-License-Identifier: GPL-3.0-or-later
-- Small WoW map-art preview. Pins always reflect attributed, recorded/reference
-- coordinates; no generated illustration is passed off as geographic map art.
local _, ns = ...
ns.zoneMap = {}
local M = ns.zoneMap
local pool = setmetatable({}, {__mode = "k"})

function M.layout(layer, textures, width, height)
  if type(layer) ~= "table" or type(textures) ~= "table" then return {} end
  local totalW, totalH = tonumber(layer.layerWidth), tonumber(layer.layerHeight)
  local tileW, tileH = tonumber(layer.tileWidth), tonumber(layer.tileHeight)
  if not totalW or not totalH or not tileW or not tileH
      or totalW <= 0 or totalH <= 0 or tileW <= 0 or tileH <= 0 then return {} end
  local cols = math.ceil(totalW / tileW)
  local rows = math.ceil(totalH / tileH)
  local out = {}
  for y = 0, rows - 1 do
    for x = 0, cols - 1 do
      local index = y * cols + x + 1
      local texture = textures[index]
      if texture and texture ~= 0 and texture ~= "" then
        out[#out + 1] = {texture = texture,
          x = x * tileW / totalW * width, y = y * tileH / totalH * height,
          w = math.min(tileW, totalW - x * tileW) / totalW * width,
          h = math.min(tileH, totalH - y * tileH) / totalH * height,
          u = math.min(1, (totalW - x * tileW) / tileW),
          v = math.min(1, (totalH - y * tileH) / tileH)}
      end
    end
  end
  return out
end

local function validTile(texture)
  return type(texture) == "string" and texture ~= ""
    or type(texture) == "number" and texture > 0
end

-- World map clients can expose multiple art layers and missing/zero file IDs.
-- Prefer a complete layer; otherwise show the most complete and label the gap.
function M.artForMap(mapID, w, h)
  if type(C_Map) ~= "table" or type(C_Map.GetMapArtLayers) ~= "function"
      or type(C_Map.GetMapArtLayerTextures) ~= "function" then
    return {}, 0, 0, w, h, {reason = "Map art APIs missing", tiles = 0}
  end
  local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
  if not ok or type(layers) ~= "table" then
    return {}, 0, 0, w, h, {reason = "No art layers", tiles = 0}
  end
  local best, bestInfo
  for index, layer in ipairs(layers) do
    local aw, ah, tw, th = tonumber(layer.layerWidth),
      tonumber(layer.layerHeight), tonumber(layer.tileWidth),
      tonumber(layer.tileHeight)
    if aw and ah and tw and th and aw > 0 and ah > 0 and tw > 0 and th > 0 then
      local got, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, index)
      if got and type(textures) == "table" then
        local expected = math.ceil(aw / tw) * math.ceil(ah / th)
        local present = 0
        for i = 1, expected do
          if validTile(textures[i]) then present = present + 1 end
        end
        local score = present / math.max(1, expected)
        if not best or score > bestInfo.coverage
            or (score == bestInfo.coverage and aw * ah > bestInfo.area) then
          best = {layer = layer, textures = textures, width = aw, height = ah}
          bestInfo = {layer = index, tiles = present, expected = expected,
            coverage = score, area = aw * ah}
        end
      end
    end
  end
  if not best then
    return {}, 0, 0, w, h, {reason = "No valid tiles", tiles = 0}
  end
  local scale = math.min(w / best.width, h / best.height)
  local vw, vh = best.width * scale, best.height * scale
  local ox, oy = (w - vw) / 2, (h - vh) / 2
  local tiles = M.layout(best.layer, best.textures, vw, vh)
  return tiles, ox, oy, vw, vh, bestInfo
end

function M.describe(mapID)
  if type(mapID) ~= "number" then return "No map selected" end
  local tiles, _, _, _, _, meta = M.artForMap(mapID, 275, 195)
  return string.format("Map %d art: layer %s; %d/%d valid tiles; %d drawn",
    mapID, tostring(meta.layer or "none"), meta.tiles or 0,
    meta.expected or 0, #tiles)
end

local function state(parent)
  local s = pool[parent]
  if s then return s end
  s = {tiles = {}, pins = {}}
  pool[parent] = s
  s.fallback = parent:CreateTexture(nil, "BACKGROUND")
  s.fallback:SetAllPoints()
  s.fallback:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\lakeshore-banner")
  s.fallback:SetVertexColor(0.65, 0.8, 0.85, 0.55)
  s.caption = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  s.caption:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
  s.caption:SetWidth(250)
  s.caption:SetJustifyH("LEFT")
  return s
end

local function pin(parent, s, index)
  local b = s.pins[index]
  if b then return b end
  b = CreateFrame("Button", nil, parent)
  b:SetSize(19, 19)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  t:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  b.icon = t
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local loc = self.location
    GameTooltip:AddLine(loc.label or "Fishing Atlas observation")
    GameTooltip:AddLine("Source: " .. (loc.source or "unknown"), 0.6, 0.8, 0.85)
    GameTooltip:AddLine(loc.kind == "school_live_nearby"
        and "Recently visible nearby school; player position, not exact pool"
        or (loc.kind == "school_guide"
        and "Historical reference; not a guaranteed active school"
        or (loc.near and "Nearby player coordinates, not NPC spawn"
        or (loc.kind == "school" and "Object/observation position; check source"
          or "Sourced reference/observation"))), 1, 0.9, 0.5)
    GameTooltip:AddLine(string.format("Map %d: %.1f, %.1f",
      loc.mapID, loc.x * 100, loc.y * 100), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:SetScript("OnClick", function(self)
    local loc = self.location
    if type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function" then
      local ok = pcall(TomTom.AddWaypoint, TomTom, loc.mapID, loc.x, loc.y,
        {title = "Fishing Atlas: " .. loc.label .. " [" .. loc.source .. "]", persistent = false})
      if ok and ns.commands then ns.commands.say("TomTom waypoint created") end
    elseif ns.commands then ns.commands.say("TomTom unavailable") end
  end)
  s.pins[index] = b
  return b
end

function M.render(parent, mapID, locations)
  if not parent or type(CreateFrame) ~= "function" then return false end
  local s = state(parent)
  for _, tile in ipairs(s.tiles) do tile:Hide() end
  for _, marker in ipairs(s.pins) do marker:Hide() end
  if type(mapID) ~= "number" then
    s.fallback:Show()
    s.caption:SetText("Choose a zone to view its map")
    return false
  end
  local width, height = parent:GetWidth(), parent:GetHeight()
  if not width or width <= 0 or not height or height <= 0 then return false end
  local tiles, ox, oy, vw, vh, info = M.artForMap(mapID, width, height)
  ox, oy, vw, vh = ox or 0, oy or 0, vw or width, vh or height
  s.fallback:Show() -- Fill missing tiles instead of leaving hard black rectangles
  for index, tile in ipairs(tiles) do
    if index > 36 then break end
    local texture = s.tiles[index]
    if not texture then
      texture = parent:CreateTexture(nil, "BACKGROUND")
      s.tiles[index] = texture
    end
    texture:SetTexture(tile.texture)
    texture:SetTexCoord(0, tile.u, 0, tile.v)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", ox + tile.x, -(oy + tile.y))
    texture:SetSize(tile.w, tile.h)
    texture:Show()
  end
  local count = 0
  local pinLimit = width >= 500 and 300 or 80
  for _, loc in ipairs(locations or {}) do
    if count >= pinLimit then break end
    if loc.mapID == mapID and ns.util.validCoordinate(loc.x) and ns.util.validCoordinate(loc.y) then
      count = count + 1
      local marker = pin(parent, s, count)
      marker.location = loc
      if loc.kind == "school_live_nearby" then
        marker.icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
        marker.icon:SetVertexColor(0.35, 1, 0.55, 1)
      elseif loc.kind == "school_guide" then
        marker.icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_02")
        marker.icon:SetVertexColor(1, 0.8, 0.35, 0.9)
      elseif loc.kind == "school" then
        marker.icon:SetTexture("Interface\\Icons\\Trade_Fishing")
        marker.icon:SetVertexColor(0.65, 0.95, 1, 1)
      elseif loc.kind == "vendor" then
        marker.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
        marker.icon:SetVertexColor(1, 0.92, 0.6, 1)
      else
        marker.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
        marker.icon:SetVertexColor(0.75, 1, 0.75, 1)
      end
      marker:ClearAllPoints()
      marker:SetPoint("CENTER", parent, "TOPLEFT", ox + loc.x * vw, -(oy + loc.y * vh))
      marker:Show()
    end
  end
  if #tiles == 0 then
    s.caption:SetText("Map artwork missing | open the full World Map")
  elseif info and info.tiles < info.expected then
    s.caption:SetText("Map " .. mapID .. " | partial client art (" ..
      info.tiles .. "/" .. info.expected .. " tiles)")
  else
    s.caption:SetText("Map " .. mapID .. " | " .. count .. " sourced positions")
  end
  return #tiles > 0
end
