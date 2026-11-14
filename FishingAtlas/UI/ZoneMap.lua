-- SPDX-License-Identifier: GPL-3.0-or-later
-- Small WoW map-art preview. Pins always reflect attributed, recorded/reference
-- coordinates; no generated illustration is passed off as geographic map art.
local _, ns = ...
ns.zoneMap = {}
local M = ns.zoneMap
local pool = setmetatable({}, {__mode = "k"})
local requested = {}

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
  if not requested[mapID] then
    requested[mapID] = true
    if type(C_Map.RequestPreloadMap) == "function" then
      pcall(C_Map.RequestPreloadMap, mapID)
    end
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
            coverage = score, area = aw * ah, width = aw, height = ah,
            tileWidth = tw, tileHeight = th}
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

-- The map-art tiles are only the *base* map. Classic clients draw
-- explored terrain in a second layer. Counting 12/12 base file IDs does NOT
-- prove the visible terrain is complete. Use the client's own exploration
-- overlays instead of treating all the dark rectangles as unloaded textures.
-- Exploration is character-specific. Never invent uncovered terrain imagery.
function M.explorationLayout(records, totalW, totalH, ox, oy, viewW, viewH)
  local out = {}
  if type(records) ~= "table" or not totalW or not totalH
      or totalW <= 0 or totalH <= 0 then return out end
  local scaleX, scaleY = viewW / totalW, viewH / totalH
  for _, record in ipairs(records) do
    if type(record) == "table" and not record.isShownByMouseOver then
      local ow, oh = tonumber(record.textureWidth), tonumber(record.textureHeight)
      local dx, dy = tonumber(record.offsetX), tonumber(record.offsetY)
      if ow and oh and dx and dy and ow > 0 and oh > 0
          and type(record.fileDataIDs) == "table" then
        local pieces = M.layout({layerWidth = ow, layerHeight = oh,
          tileWidth = 256, tileHeight = 256},
          record.fileDataIDs, ow * scaleX, oh * scaleY)
        for _, tile in ipairs(pieces) do
          local x, y = dx * scaleX + tile.x, dy * scaleY + tile.y
          local left, top = math.max(0, x), math.max(0, y)
          local right = math.min(viewW, x + tile.w)
          local bottom = math.min(viewH, y + tile.h)
          if right > left and bottom > top and tile.w > 0 and tile.h > 0 then
            local u0 = (left - x) / tile.w * tile.u
            local v0 = (top - y) / tile.h * tile.v
            local u1 = (right - x) / tile.w * tile.u
            local v1 = (bottom - y) / tile.h * tile.v
            out[#out + 1] = {texture = tile.texture,
              x = ox + left, y = oy + top, w = right - left,
              h = bottom - top, u0 = u0, v0 = v0, u1 = u1, v1 = v1}
          end
        end
      end
    end
  end
  return out
end

-- Complete historical overlays are a fallback for character-specific fog
-- of war. They are not available through the exploration API until a zone is
-- explored, so the old renderer could only draw the dark base tiles.
-- Historical DB2 IDs MUST match the art the running client actually uses.
function M.fullOverlayRecords(mapID, meta)
  if not meta or not meta.width or not meta.height
      or meta.layer ~= 1 or type(C_Map) ~= "table"
      or type(C_Map.GetMapArtID) ~= "function" then
    return nil, "art-id API unavailable or non-base art layer"
  end
  local ok, artID = pcall(C_Map.GetMapArtID, mapID)
  if not ok or type(artID) ~= "number" then
    return nil, "art-id unavailable"
  end
  local pack = ns.data and ns.data.classicMapOverlays or {}
  local refs = pack[artID]
  if not refs then return nil, "no indexed overlays for art " .. artID, artID end
  if refs[1] ~= meta.tileWidth or refs[2] ~= meta.tileHeight then
    return nil, "reference tile size mismatch for art " .. artID, artID
  end
  local records = {}
  for index = 3, #refs do
    local record = refs[index]
    if type(record) == "table" and #record >= 5 then
      local ids = {}
      for i = 5, #record do
        if validTile(record[i]) then ids[#ids + 1] = record[i] end
      end
      if #ids > 0 then
        records[#records + 1] = {
          textureWidth = record[1], textureHeight = record[2],
          offsetX = record[3], offsetY = record[4], fileDataIDs = ids,
        }
      end
    end
  end
  if #records == 0 then return nil, "indexed art contains no valid overlays", artID end
  return records, "historical_full_reference", artID
end

function M.exploredForMap(mapID, meta, ox, oy, viewW, viewH)
  if not meta or not meta.width or not meta.height then
    return {}, "map layer unavailable"
  end
  local historical, source, artID = M.fullOverlayRecords(mapID, meta)
  if historical then
    return M.explorationLayout(historical, meta.width, meta.height,
      ox, oy, viewW, viewH), source, artID
  end
  if type(C_MapExplorationInfo) ~= "table"
      or type(C_MapExplorationInfo.GetExploredMapTextures) ~= "function" then
    return {}, source or "exploration API unavailable", artID
  end
  local ok, records = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
  if not ok then return {}, "exploration API failed", artID end
  return M.explorationLayout(records, meta.width, meta.height,
    ox, oy, viewW, viewH), "character_exploration", artID
end

-- Differentiate references provided by C_Map from textures that have
-- actually finished loading in this instance of the preview. A nonzero
-- FileDataID is NOT proof of successful rendering on a newer Forever build.
local function previewLoadStatus(mapID)
  local chosen, width
  for parent, state in pairs(pool) do
    if state.renderedMap == mapID then
      local currentWidth = parent.GetWidth and parent:GetWidth() or 0
      if not chosen or currentWidth < width then
        chosen, width = state, currentWidth
      end
    end
  end
  if not chosen then return nil end
  local report = {loaded = 0, pending = 0, unknown = 0,
    assigned = 0, unavailable = {}}
  for index, fileID in ipairs(chosen.tileIDs or {}) do
    local tile = chosen.tiles[index]
    if tile and fileID then
      report.assigned = report.assigned + 1
      local loaded
      if type(tile.IsObjectLoaded) == "function" then
        local ok, value = pcall(tile.IsObjectLoaded, tile)
        if ok and type(value) == "boolean" then loaded = value end
      end
      if loaded == true then
        report.loaded = report.loaded + 1
      elseif loaded == false then
        report.pending = report.pending + 1
        if #report.unavailable < 12 then
          report.unavailable[#report.unavailable + 1] =
            tostring(index) .. ":" .. tostring(fileID)
        end
      else
        report.unknown = report.unknown + 1
      end
    end
  end
  return report
end

function M.describe(mapID)
  if type(mapID) ~= "number" then return "No map selected" end
  local tiles, ox, oy, w, h, meta = M.artForMap(mapID, 275, 195)
  local explored, source, artID = M.exploredForMap(mapID, meta, ox, oy, w, h)
  local summary = string.format(
    "Map %d: layer %s; %d/%d base file references; %d layout tiles; %d overlay tiles (%s, art %s)",
    mapID, tostring(meta.layer or "none"), meta.tiles or 0,
    meta.expected or 0, #tiles, #explored, tostring(source), tostring(artID))
  local preview = previewLoadStatus(mapID)
  if not preview then
    return summary .. " | no matching visible preview for load test"
  end
  if preview.unknown == preview.assigned then
    return summary .. " | texture-load API unavailable in this client"
  end
  local detail = string.format(
    " | preview: %d/%d loaded, %d pending, %d unknown",
    preview.loaded, preview.assigned, preview.pending, preview.unknown)
  if #preview.unavailable > 0 then
    detail = detail .. " | pending slots (slot:fileID) " ..
      table.concat(preview.unavailable, ",")
  end
  return summary .. detail
end

local function state(parent)
  local s = pool[parent]
  if s then return s end
  s = {tiles = {}, explored = {}, pins = {}}
  pool[parent] = s
  s.fallback = parent:CreateTexture(nil, "BACKGROUND")
  s.fallback:SetAllPoints()
  -- A neutral backing identifies unexplored regions without showing an
  -- unrelated panorama through an apparent map-art "hole".
  s.fallback:SetTexture("Interface\\Buttons\\WHITE8X8")
  s.fallback:SetVertexColor(0.03, 0.06, 0.08, 1)
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
  for _, tile in ipairs(s.explored) do tile:Hide() end
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
  s.renderedMap, s.tileIDs = mapID, {}
  -- Retain the safe local fallback when this client lacks world-map tiles.
  s.fallback:Show()
  -- Some map assets arrive after the first request. Retry once, without an
  -- OnUpdate loop that would hammer C_Map during ordinary gameplay.
  if s.requestedMap ~= mapID then
    s.requestedMap, s.retries, s.retryScheduled = mapID, 0, false
  end
  -- Some art is streamed asynchronously. Retry at most three times, only
  -- while this preview is visible. Never poll every frame or use stale maps.
  -- Presence of file IDs is not proof their textures have finished streaming.
  -- Retry a couple of complete 12/12 maps too, not only sparse-ID maps.
  -- This is bounded to 3 retries and never calls protected map operations.
  if (info and info.expected and info.tiles < info.expected
      or (s.retries or 0) < 2 and #tiles > 0)
      and (s.retries or 0) < 3 and not s.retryScheduled
      and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
    s.retryScheduled = true
    local attempt = s.retries + 1
    C_Timer.After(attempt * 2, function()
      if s.requestedMap ~= mapID then return end
      s.retryScheduled, s.retries = false, attempt
      if parent:IsShown() then M.render(parent, mapID, locations) end
    end)
  end
  for index, tile in ipairs(tiles) do
    if index > 256 then break end
    local texture = s.tiles[index]
    if not texture then
      texture = parent:CreateTexture(nil, "BACKGROUND")
      s.tiles[index] = texture
    end
    s.tileIDs[index] = tile.texture
    texture:SetTexture(tile.texture)
    texture:SetTexCoord(0, tile.u, 0, tile.v)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", ox + tile.x, -(oy + tile.y))
    texture:SetSize(tile.w, tile.h)
    texture:Show()
  end
  -- Add exploration art above the base, exactly as the WoW World Map does.
  -- A 12/12 base count can still show large fogged/blank rectangles without
  -- these additional client-owned textures.
  local explored, overlaySource = M.exploredForMap(mapID, info, ox, oy, vw, vh)
  s.overlaySource = overlaySource
  for index, part in ipairs(explored) do
    if index > 600 then break end
    local texture = s.explored[index]
    if not texture then
      texture = parent:CreateTexture(nil, "ARTWORK")
      s.explored[index] = texture
    end
    texture:SetTexture(part.texture)
    texture:SetTexCoord(part.u0, part.u1, part.v0, part.v1)
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", parent, "TOPLEFT", part.x, -part.y)
    texture:SetSize(part.w, part.h)
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
    s.caption:SetText("Missing client map tiles | use World Map")
  elseif info and info.tiles < info.expected then
    s.caption:SetText("Map " .. mapID .. " | partial client art (" ..
      info.tiles .. "/" .. info.expected .. " tiles)")
  else
    s.caption:SetText("Map " .. mapID .. " | " .. #explored ..
      (overlaySource == "historical_full_reference" and " full reference" or " explored") ..
      " tiles | " .. count .. " sourced pins")
  end
  return #tiles > 0
end
