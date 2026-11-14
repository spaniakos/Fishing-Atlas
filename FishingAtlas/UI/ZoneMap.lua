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
      if texture then
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

local function art(mapID, w, h)
  if type(C_Map) ~= "table" or type(C_Map.GetMapArtLayers) ~= "function"
      or type(C_Map.GetMapArtLayerTextures) ~= "function" then return {} end
  local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
  if not ok or type(layers) ~= "table" or not layers[1] then return {} end
  local layer = layers[1]
  local result, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
  if not result or type(textures) ~= "table" then return {} end
  local aw, ah = tonumber(layer.layerWidth), tonumber(layer.layerHeight)
  if not aw or not ah or aw <= 0 or ah <= 0 then return {} end
  local scale = math.min(w / aw, h / ah)
  local vw, vh = aw * scale, ah * scale
  local ox, oy = (w - vw) / 2, (h - vh) / 2
  return M.layout(layer, textures, vw, vh), ox, oy, vw, vh
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
    GameTooltip:AddLine(loc.kind == "school_guide"
        and "Published guide lead, not a guaranteed active school"
        or (loc.near and "Nearby player coordinates, not NPC spawn"
        or (loc.kind == "school" and "Object/observation position; check source"
          or "Sourced reference/observation")), 1, 0.9, 0.5)
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
  local tiles, ox, oy, vw, vh = art(mapID, width, height)
  ox, oy, vw, vh = ox or 0, oy or 0, vw or width, vh or height
  s.fallback:SetShown(#tiles == 0)
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
  for _, loc in ipairs(locations or {}) do
    if count >= 40 then break end
    if loc.mapID == mapID and ns.util.validCoordinate(loc.x) and ns.util.validCoordinate(loc.y) then
      count = count + 1
      local marker = pin(parent, s, count)
      marker.location = loc
      if loc.kind == "school_guide" then
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
    s.caption:SetText("Client map artwork unavailable | use World Map")
  else
    s.caption:SetText("Map " .. mapID .. " | " .. count .. " sourced positions")
  end
  return #tiles > 0
end
