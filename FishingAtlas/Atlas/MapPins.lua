-- SPDX-License-Identifier: GPL-3.0-or-later
-- Sourced WorldMapFrame overlays: personal places and confirmed independent observations.
local _, ns = ...
ns.mapPins = {}
local M = ns.mapPins
local MAX_PINS = 120
local pins, lastMap, lastCount = {}, nil, -1
local elapsed = 0

function M.points(mapID)
  local out = {}
  for _, node in ipairs(ns.storage.inZone(mapID)) do
    if ns.util.validCoordinate(node.x) and ns.util.validCoordinate(node.y) then
      out[#out + 1] = {x = node.x, y = node.y, label = node.label,
        kind = "player_position", verifiedSpawn = false}
    end
  end
  for _, node in ipairs(ns.schools.inZone(mapID)) do
    out[#out + 1] = {x = node.x, y = node.y, label = node.label,
      kind = "school_candidate", verifiedSpawn = false}
  end
  if ns.sources then
    for _, school in ipairs(ns.sources.schools()) do
      for _, loc in ipairs(school.spots or {}) do
        if loc.mapID == mapID and (loc.installs or 0) >= 3
            and ns.util.validCoordinate(loc.x) and ns.util.validCoordinate(loc.y) then
          out[#out + 1] = {x = loc.x, y = loc.y, label = school.name,
            kind = "observed_school", verifiedSpawn = true}
        end
      end
    end
  end
  return out
end

local function hidePins()
  for _, pin in ipairs(pins) do pin:Hide() end
end

function M.refresh()
  local settings = ns.storage.db and ns.storage.db.settings
  if settings and settings.mapPins == false then hidePins(); return false end
  local map = WorldMapFrame
  if not map or not map.IsShown or not map:IsShown() then hidePins(); return false end
  local scroll = map.ScrollContainer
  local canvas = scroll and (scroll.Child or (scroll.GetScrollChild and scroll:GetScrollChild()))
  local mapID = type(map.GetMapID) == "function" and map:GetMapID() or nil
  if not canvas or type(canvas.GetWidth) ~= "function" or type(canvas.GetHeight) ~= "function"
      or not mapID or type(CreateFrame) ~= "function" then hidePins(); return false end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  if not w or not h or w <= 0 or h <= 0 then hidePins(); return false end
  local candidates = M.points(mapID)
  local count = math.min(MAX_PINS, #candidates)
  if mapID == lastMap and count == lastCount then return true end
  lastMap, lastCount = mapID, count
  hidePins()
  for i = 1, count do
    local loc = candidates[i]
    local pin = pins[i]
    if not pin then
      pin = CreateFrame("Frame", nil, canvas)
      pin:SetSize(15, 15)
      local texture = pin:CreateTexture(nil, "OVERLAY")
      texture:SetAllPoints()
      texture:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
      pin.marker = texture
      pins[i] = pin
    end
    pin:SetParent(canvas)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", w * loc.x, -h * loc.y)
    if pin.marker.SetVertexColor then
      if loc.kind == "observed_school" then
        pin.marker:SetTexture("Interface\\Icons\\Trade_Fishing")
        pin.marker:SetVertexColor(0.6, 1, 0.9, 0.95)
      elseif loc.kind == "school_candidate" then
        pin.marker:SetTexture("Interface\\Icons\\Trade_Fishing")
        pin.marker:SetVertexColor(1, 0.65, 0.12, 0.9)
      else
        pin.marker:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
        pin.marker:SetVertexColor(0.1, 0.8, 0.8, 0.85)
      end
    end
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
      lastMap, lastCount = nil, -1
      M.refresh()
    end
  end)
  M.driver = frame
end
