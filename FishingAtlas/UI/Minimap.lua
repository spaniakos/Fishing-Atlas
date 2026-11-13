-- SPDX-License-Identifier: GPL-3.0-or-later
local _, ns = ...
ns.minimap = {}
local M = ns.minimap
local button

local function settings()
  return ns.storage.db and ns.storage.db.settings
end

function M.coordinates(angle)
  local r = math.rad(tonumber(angle) or 210)
  return math.cos(r) * 80, math.sin(r) * 80
end

function M.update()
  if not button then return end
  local saved = settings()
  if saved and saved.showMinimap == false then button:Hide(); return end
  if not Minimap then button:Hide(); return end
  button:ClearAllPoints()
  local x, y = M.coordinates(saved and saved.minimapAngle)
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
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetTexture("Interface\\Icons\\Trade_Fishing")
  icon:SetPoint("CENTER", button, "CENTER", 0, 1)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(52, 52)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT", button, "TOPLEFT")
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
