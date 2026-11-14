-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native WorldMapFrame pins share the explorer's evidence-aware marker model.
local _, ns = ...
ns.mapPins = {}
local M = ns.mapPins
local MAX_PINS = 120
local pins, lastMap, lastSignature, lastCanvas, lastW, lastH = {}, nil, nil, nil, nil, nil
local elapsed = 0

function M.points(mapID)
  local selected = ns.ui and ns.ui.selected and ns.ui.selected() or nil
  local focus = ns.ui and ns.ui.selectedPoint or nil
  if not ns.mapMarkers then return {} end
  return ns.mapMarkers.collect(selected, mapID, focus)
end

local function hidePins()
  for _, pin in ipairs(pins) do pin:Hide() end
  lastMap, lastSignature, lastCanvas, lastW, lastH = nil, nil, nil, nil, nil
end

local function iconFor(loc)
  if loc.isSelected then
    return "Interface\\Icons\\INV_Misc_Map_01", 0.98, 0.93, 0.35, 1
  elseif loc.kind == "school_live_nearby" then
    return "Interface\\Icons\\INV_Misc_Fish_02", 0.3, 1, 0.55, 0.98
  elseif loc.kind == "school_candidate" or loc.kind == "school_classic_reference"
      or loc.kind == "school_guide" then
    return "Interface\\Icons\\Trade_Fishing", 1, 0.65, 0.12, 0.9
  elseif loc.kind == "observed_school" then
    return "Interface\\Icons\\Trade_Fishing", 0.6, 1, 0.9, 0.95
  elseif loc.kind == "vendor" or loc.kind == "npc" then
    return "Interface\\Icons\\INV_Misc_Bag_10", 1, 0.83, 0.44, 1
  end
  return "Interface\\Icons\\INV_Misc_Map_01", 0.1, 0.8, 0.8, 0.85
end

function M.refresh()
  local settings = ns.storage.db and ns.storage.db.settings
  if settings and settings.mapPins == false then hidePins(); return false end
  local map = WorldMapFrame
  if not map or not map.IsShown or not map:IsShown() then
    hidePins(); return false
  end
  local scroll = map.ScrollContainer
  local canvas = scroll and (scroll.Child or
    (scroll.GetScrollChild and scroll:GetScrollChild()))
  local mapID = type(map.GetMapID) == "function" and map:GetMapID() or nil
  if not canvas or type(canvas.GetWidth) ~= "function"
      or type(canvas.GetHeight) ~= "function" or not mapID
      or type(CreateFrame) ~= "function" then hidePins(); return false end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  if not w or not h or w <= 0 or h <= 0 then hidePins(); return false end
  local candidates = M.points(mapID)
  local count = math.min(MAX_PINS, #candidates)
  local visible = {}
  for i = 1, count do visible[i] = candidates[i] end
  local signature = ns.mapMarkers and ns.mapMarkers.signature(visible) or ""
  if mapID == lastMap and signature == lastSignature and canvas == lastCanvas
      and w == lastW and h == lastH then return true end
  hidePins()
  lastMap, lastSignature, lastCanvas, lastW, lastH = mapID, signature, canvas, w, h
  for i, loc in ipairs(visible) do
    local pin = pins[i]
    if not pin then
      pin = CreateFrame("Button", nil, canvas)
      pin:SetSize(16, 16)
      local texture = pin:CreateTexture(nil, "OVERLAY")
      texture:SetAllPoints()
      pin.marker = texture
      pin:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local point = self.location
        if not point then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(point.label)
        GameTooltip:AddLine("Source: " .. point.source, 0.6, 0.8, 0.85)
        if point.kind == "school_live_nearby" then
          GameTooltip:AddLine("Nearby player position, not exact pool", 1, 0.9, 0.5)
        end
        GameTooltip:Show()
      end)
      pin:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
      end)
      pin:SetScript("OnClick", function(self)
        local point = self.location
        if point and type(TomTom) == "table"
            and type(TomTom.AddWaypoint) == "function" then
          pcall(TomTom.AddWaypoint, TomTom, point.mapID, point.x, point.y,
            {title = "Fishing Atlas: " .. point.label, persistent = false})
        end
      end)
      pins[i] = pin
    end
    pin:SetParent(canvas)
    pin.location = loc
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", w * loc.x, -h * loc.y)
    local icon, r, g, b, a = iconFor(loc)
    pin.marker:SetTexture(icon)
    pin.marker:SetVertexColor(r, g, b, a)
    pin:Show()
  end
  return true
end

function M.start()
  if type(CreateFrame) ~= "function" or M.driver then return end
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + (delta or 0)
    if elapsed >= 2 then
      elapsed = 0
      M.refresh()
    end
  end)
  M.driver = frame
end
