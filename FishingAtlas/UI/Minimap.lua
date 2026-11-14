-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.minimap = {}
local M = ns.minimap
local button

local function settings()
  return ns.storage.db and ns.storage.db.settings
end

function M.coordinates(angle, radius)
  local r = math.rad(tonumber(angle) or 210)
  radius = tonumber(radius) or 80
  return math.cos(r) * radius, math.sin(r) * radius
end

function M.update()
  if not button then return end
  local saved = settings()
  if saved and saved.showMinimap == false then button:Hide(); return end
  if not Minimap then button:Hide(); return end
  button:ClearAllPoints()
  local radius = 80
  if type(Minimap.GetWidth) == "function" and type(Minimap.GetHeight) == "function" then
    local extent = math.max(Minimap:GetWidth() or 0, Minimap:GetHeight() or 0)
    if extent > 0 then radius = extent / 2 + 17 end
  end
  local x, y = M.coordinates(saved and saved.minimapAngle, radius)
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
  button:Show()
end

local function drag()
  if type(GetCursorPosition) ~= "function" or not Minimap then return end
  local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1
  if scale <= 0 then return end
  local cx, cy = GetCursorPosition()
  local mx, my = Minimap:GetCenter()
  local dx, dy = cx / scale - mx, cy / scale - my
  local angle
  if math.atan2 then
    angle = math.deg(math.atan2(dy, dx))
  elseif dx == 0 then
    angle = dy >= 0 and 90 or 270
  else
    angle = math.deg(math.atan(dy / dx))
    if dx < 0 then angle = angle + 180 end
  end
  if settings() then settings().minimapAngle = angle end
  M.update()
end

function M.start()
  if button or type(CreateFrame) ~= "function" or not Minimap then return end
  button = CreateFrame("Button", "FishingAtlasMinimapButton", Minimap)
  button:SetSize(34, 34)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(32, 32)
  icon:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\atlas-emblem")
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  -- The custom emblem already has a brass ring. Do not overlay Blizzard's
  -- tracking border, which creates the doubled, offset rings seen in v0.99.6.
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, which)
    if which == "RightButton" then
      if ns.options then ns.options.open() end
    elseif ns.ui then ns.ui.toggle() end
  end)
  button:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Fishing Atlas")
    GameTooltip:AddLine("Left click: explorer", 1, 1, 1)
    GameTooltip:AddLine("Right click: settings", 1, 1, 1)
    GameTooltip:AddLine("Drag: reposition", 0.8, 0.8, 0.8)
    local meta = ns.sources and ns.sources.metadata() or {}
    if meta.dataAsOf then
      GameTooltip:AddLine("Observed data as of " .. meta.dataAsOf, 0.6, 0.9, 1)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", drag)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    drag()
  end)
  M.update()
end
