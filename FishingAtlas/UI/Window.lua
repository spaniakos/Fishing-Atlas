-- SPDX-License-Identifier: GPL-3.0-or-later
-- Read-only, scrollable atlas explorer. This avoids inferred game-world facts.
local _, ns = ...
ns.ui = {}
local UI = ns.ui
local categories = {"fish", "gear", "recipes", "zones", "schools", "vendors", "journal"}
local visibleRows, rowHeight = 13, 31
UI.category, UI.query, UI.offset = "fish", "", 0
local frame, search, countText, detailTitle, detailInfo, detailIcon, statusText
local listSlider, detailScroll, detailChild, results = nil, nil, nil, {}
local rows, tabs, contextButtons = {}, {}, {}
local selected, context, alertButton, pinButton
local refreshBusy = false

local function makeLabel(parent, fontName, width, height)
  local label = parent:CreateFontString(nil, "OVERLAY", fontName or "GameFontHighlight")
  label:SetSize(width, height)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  return label
end

local function panel(parent, width, height, x, y, r, g, b)
  local child = CreateFrame("Frame", nil, parent)
  child:SetSize(width, height)
  child:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local bg = child:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(r or 0.09, g or 0.15, b or 0.18, 0.96)
  child.background = bg
  return child
end

local function button(parent, name, x, y, width, height, click)
  local control = CreateFrame("Button", nil, parent)
  control:SetSize(width, height)
  control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local bg = control:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\bronze-button")
  bg:SetVertexColor(0.82, 0.9, 0.98, 1)
  control.background = bg
  local label = makeLabel(control, "GameFontNormalSmall", width - 15, height - 5)
  label:SetPoint("LEFT", control, "LEFT", 8, 0)
  label:SetJustifyV("MIDDLE")
  label:SetText(name)
  control.label = label
  control:SetScript("OnClick", click)
  return control
end

local function tooltip(row, anchor)
  if not GameTooltip or not row then return end
  GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
  local kind, id = ns.browser.tooltip(row)
  local ok = false
  if kind == "item" and type(GameTooltip.SetItemByID) == "function" then
    ok = pcall(GameTooltip.SetItemByID, GameTooltip, id)
  elseif kind == "spell" and type(GameTooltip.SetSpellByID) == "function" then
    ok = pcall(GameTooltip.SetSpellByID, GameTooltip, id)
  end
  if not ok then GameTooltip:AddLine(row.name) end
  GameTooltip:AddLine("Atlas source: " .. tostring(row.confidence), 0.3, 0.85, 0.8)
  GameTooltip:Show()
end

local function updateSettings()
  local settings = ns.storage.db and ns.storage.db.settings or {}
  if alertButton then
    alertButton.label:SetText("Alerts: " .. (settings.notifications and "ON" or "OFF"))
  end
  if pinButton then
    pinButton.label:SetText("Map pins: " .. (settings.mapPins and "ON" or "OFF"))
  end
end

local function sendWaypoint(target)
  if not target then return false end
  if type(TomTom) ~= "table" or type(TomTom.AddWaypoint) ~= "function" then
    ns.commands.say("TomTom is not available"); return false
  end
  local ok = pcall(TomTom.AddWaypoint, TomTom, target.mapID, target.x, target.y,
    {title = "Fishing Atlas: " .. target.label, persistent = false})
  if ok then ns.commands.say("Waypoint added for a saved player location") end
  return ok
end

local function renderDetail(row)
  selected = row
  if not row then
    detailTitle:SetText("Select a record")
    detailInfo:SetText("Scroll to browse. Right-click for available context actions.")
    detailIcon:SetTexture("Interface\\Icons\\Trade_Fishing")
    return
  end
  detailTitle:SetText(row.name)
  detailIcon:SetTexture(ns.browser.icon(row))
  local info = table.concat(ns.browser.details(row), "\n\n")
  detailInfo:SetText(info)
  local height = math.max(300, detailInfo:GetStringHeight() + 20)
  detailChild:SetHeight(height)
  detailScroll:SetVerticalScroll(0)
end

local function hideContext()
  if context then context:Hide() end
end

local function showContext(row, anchor)
  if not context then return end
  local waypoint = ns.browser.waypoint(row)
  context:ClearAllPoints()
  context:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 10, 2)
  contextButtons[1].label:SetText("View details")
  contextButtons[1]:SetScript("OnClick", function()
    hideContext()
    renderDetail(row)
  end)
  local button2 = contextButtons[2]
  button2.label:SetText(waypoint and "TomTom: saved location" or "No verified waypoint")
  if waypoint then
    button2:SetScript("OnClick", function() hideContext(); sendWaypoint(waypoint) end)
    button2:Enable()
  else
    button2:SetScript("OnClick", function() hideContext() end)
    button2:Disable()
  end
  context:Show()
end

function UI.scroll(delta)
  local maxOffset = math.max(0, #results - visibleRows)
  UI.offset = math.min(maxOffset, math.max(0, UI.offset - delta))
  UI.draw()
end

function UI.draw()
  if not frame or refreshBusy then return end
  refreshBusy = true
  countText:SetText(UI.category .. "  |  " .. #results .. " records  |  scroll to browse")
  local maxOffset = math.max(0, #results - visibleRows)
  UI.offset = math.min(maxOffset, UI.offset)
  for i, control in ipairs(rows) do
    local item = results[UI.offset + i]
    control.item = item
    if item then
      control.label:SetText(item.name:sub(1, 34))
      control.icon:SetTexture(ns.browser.icon(item))
      control:Show()
      if selected == item then control.background:SetVertexColor(0.8, 0.95, 1, 1)
      else control.background:SetVertexColor(0.55, 0.73, 0.83, 0.98) end
    else
      control:Hide()
    end
  end
  listSlider:SetMinMaxValues(0, maxOffset)
  listSlider:SetValue(UI.offset)
  for _, tab in ipairs(tabs) do
    tab.label:SetText((UI.category == tab.category and "> " or "") .. tab.category)
  end
  updateSettings()
  refreshBusy = false
end

function UI.refresh(reset)
  if not frame then return end
  if reset then UI.offset = 0 end
  results = ns.browser.list(UI.category, UI.query)
  hideContext()
  UI.draw()
end

local function build()
  if frame or type(CreateFrame) ~= "function" or not UIParent then return end
  frame = panel(UIParent, 900, 665, 0, 0, 0.04, 0.07, 0.09)
  frame.background:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\deepwater-background")
  frame.background:SetVertexColor(1, 1, 1, 1)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  local banner = frame:CreateTexture(nil, "BORDER")
  banner:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  banner:SetSize(900, 53)
  banner:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\lakeshore-banner")
  banner:SetVertexColor(0.9, 0.9, 0.9, 0.67)
  local crest = frame:CreateTexture(nil, "ARTWORK")
  crest:SetSize(49, 49)
  crest:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -2)
  crest:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\atlas-emblem")
  local title = makeLabel(frame, "GameFontNormalLarge", 710, 26)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 75, -16)
  title:SetText("Fishing Atlas  |  Forever  |  data baseline 70888")
  button(frame, "X", 851, -13, 30, 26, function() frame:Hide() end)

  for i, category in ipairs(categories) do
    local tab = button(frame, category, 18 + (i - 1) * 124, -56, 119, 30, function()
      UI.category, UI.query, UI.offset = category, "", 0
      search:SetText("")
      renderDetail(nil)
      UI.refresh(true)
    end)
    tab.category = category
    tabs[#tabs + 1] = tab
  end

  local label = makeLabel(frame, "GameFontNormalSmall", 60, 22)
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -107)
  label:SetText("Search:")
  search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  search:SetSize(550, 24)
  search:SetPoint("TOPLEFT", frame, "TOPLEFT", 93, -105)
  search:SetAutoFocus(false)
  search:SetMaxLetters(70)
  search:SetScript("OnTextChanged", function(self)
    UI.query = self:GetText() or ""
    UI.refresh(true)
  end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  countText = makeLabel(frame, "GameFontHighlightSmall", 400, 22)
  countText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -145)
  local left = panel(frame, 410, 414, 18, -174)
  local right = panel(frame, 439, 414, 442, -174, 0.08, 0.12, 0.15)
  right.background:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\deepwater-background")
  right.background:SetVertexColor(0.92, 0.92, 0.92, 1)

  local listArea = CreateFrame("Frame", nil, left)
  listArea:SetSize(385, 404)
  listArea:SetPoint("TOPLEFT", left, "TOPLEFT", 2, -4)
  listArea:EnableMouseWheel(true)
  listArea:SetScript("OnMouseWheel", function(_, delta) UI.scroll(delta * 3) end)

  for i = 1, visibleRows do
    local control = button(listArea, "", 0, -(i - 1) * rowHeight, 375, 29, function() end)
    control.label:ClearAllPoints()
    control.label:SetPoint("LEFT", control, "LEFT", 40, 0)
    control.label:SetSize(327, 25)
    control.icon = control:CreateTexture(nil, "ARTWORK")
    control.icon:SetSize(25, 25)
    control.icon:SetPoint("LEFT", control, "LEFT", 7, 0)
    control:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    control:SetScript("OnClick", function(self, key)
      if not self.item then return end
      if key == "RightButton" then showContext(self.item, self)
      else hideContext(); renderDetail(self.item); UI.draw() end
    end)
    control:SetScript("OnEnter", function(self) tooltip(self.item, self) end)
    control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    rows[i] = control
  end
  listSlider = CreateFrame("Slider", nil, left, "OptionsSliderTemplate")
  listSlider:SetOrientation("VERTICAL")
  listSlider:SetSize(14, 390)
  listSlider:SetPoint("TOPRIGHT", left, "TOPRIGHT", -7, -11)
  listSlider:SetMinMaxValues(0, 0)
  listSlider:SetValueStep(1)
  listSlider:SetScript("OnValueChanged", function(_, value)
    local newOffset = math.floor(value + 0.5)
    if newOffset ~= UI.offset then
      UI.offset = newOffset
      UI.draw()
    end
  end)

  detailIcon = right:CreateTexture(nil, "ARTWORK")
  detailIcon:SetSize(58, 58)
  detailIcon:SetPoint("TOPLEFT", right, "TOPLEFT", 14, -12)
  detailTitle = makeLabel(right, "GameFontNormalLarge", 335, 58)
  detailTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 82, -12)
  detailScroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
  detailScroll:SetPoint("TOPLEFT", right, "TOPLEFT", 15, -82)
  detailScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -30, 13)
  detailChild = CreateFrame("Frame", nil, detailScroll)
  detailChild:SetSize(375, 300)
  detailScroll:SetScrollChild(detailChild)
  detailInfo = makeLabel(detailChild, "GameFontHighlight", 366, 300)
  detailInfo:SetPoint("TOPLEFT", detailChild, "TOPLEFT", 0, 0)
  detailInfo:SetWordWrap(true)

  context = panel(frame, 226, 69, 0, 0, 0.08, 0.13, 0.17)
  context:ClearAllPoints()
  context:SetFrameStrata("TOOLTIP")
  contextButtons[1] = button(context, "View details", 3, -3, 219, 29, function() end)
  contextButtons[2] = button(context, "TomTom", 3, -35, 219, 29, function() end)
  context:Hide()

  button(frame, "Report issue", 454, -600, 155, 30, function()
    if ns.issues then ns.issues.open() end
  end)
  local hint = makeLabel(frame, "GameFontHighlightSmall", 425, 18)
  hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -605)
  hint:SetText("Right click: actions | Sources labeled | GitHub: report bugs")
  alertButton = button(frame, "Alerts", 625, -600, 124, 30, function()
    if ns.storage.db then
      local s = ns.storage.db.settings
      s.notifications = not s.notifications
      updateSettings()
    end
  end)
  pinButton = button(frame, "Map pins", 753, -600, 125, 30, function()
    if ns.storage.db then
      local s = ns.storage.db.settings
      s.mapPins = not s.mapPins
      ns.mapPins.refresh()
      updateSettings()
    end
  end)
  statusText = makeLabel(frame, "GameFontHighlightSmall", 840, 20)
  statusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -640)
  statusText:SetText("Atlas data is partial. School spawns and vendor stock require verified observations.")
  frame:Hide()
  renderDetail(nil)
end

function UI.show()
  build()
  if not frame then return false end
  frame:Show()
  UI.refresh(true)
  return true
end

function UI.toggle()
  build()
  if not frame then return false end
  if frame:IsShown() then frame:Hide() else UI.show() end
  return true
end
