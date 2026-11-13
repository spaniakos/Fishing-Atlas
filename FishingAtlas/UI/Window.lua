-- SPDX-License-Identifier: GPL-3.0-or-later
-- Fishing Atlas 0.99.5: image-3-inspired three-column explorer.
-- All controls are functional FrameXML; visuals never invent game-world data.
local _, ns = ...
ns.ui = {}
local UI = ns.ui
local W, H = 1210, 755
local rowHeight, visibleRows = 34, 12
local categories = {
  {"fish", "Fish", "Interface\\Icons\\INV_Misc_Fish_02"},
  {"recipes", "Recipes", "Interface\\Icons\\INV_Misc_Food_15"},
  {"zones", "Zones", "Interface\\Icons\\INV_Misc_Map_01"},
  {"schools", "Schools", "Interface\\Icons\\INV_Misc_Fishingpole_02"},
  {"vendors", "Vendors", "Interface\\Icons\\INV_Misc_Bag_10"},
  {"gear", "Gear", "Interface\\Icons\\Trade_Fishing"},
  {"journal", "Journal", "Interface\\Icons\\INV_Misc_Book_09"}
}
local topTabs = {"Explorer", "Journal", "Recipes", "Zones", "Schools", "Vendors", "Gear"}
local categoryFor = {Explorer = "zones", Journal = "journal", Recipes = "recipes",
  Zones = "zones", Schools = "schools", Vendors = "vendors", Gear = "gear"}
UI.category, UI.query, UI.offset = "zones", "", 0
UI.topPage = "Explorer"
UI.filterFish, UI.filterLocations, UI.detailsTab = false, false, "Overview"
local frame, search, listCount, listSlider, listRegion, headerName, headerMeta
local detailsScroll, detailsChild, mapSurface, mapCaption, zoneInfo, relatedTitle
local active, rows, sidebar, tabs, subTabs, detailRows, rightRows = nil, {}, {}, {}, {}, {}, {}
local results, details = {}, {}
local alertsButton, mapPinsButton, footerStatus, versionLabel
local uiBusy = false

local function label(parent, font, width, height, x, y)
  local txt = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  txt:SetSize(width, height)
  txt:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  txt:SetJustifyH("LEFT")
  txt:SetJustifyV("MIDDLE")
  return txt
end

local function paint(parent, color, layer)
  local art = parent:CreateTexture(nil, layer or "BACKGROUND")
  art:SetAllPoints()
  art:SetTexture("Interface\\Buttons\\WHITE8X8")
  art:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  return art
end

local function border(parent)
  local positions = {
    {"TOPLEFT", "TOPRIGHT", 1}, {"BOTTOMLEFT", "BOTTOMRIGHT", 1},
    {"TOPLEFT", "BOTTOMLEFT", 1}, {"TOPRIGHT", "BOTTOMRIGHT", 1}
  }
  for i, segment in ipairs(positions) do
    local edge = parent:CreateTexture(nil, "BORDER")
    edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    edge:SetVertexColor(0.59, 0.38, 0.10, 0.9)
    if i <= 2 then
      edge:SetHeight(segment[3])
      edge:SetPoint(segment[1], parent, segment[1], 0, 0)
      edge:SetPoint(segment[2], parent, segment[2], 0, 0)
    else
      edge:SetWidth(segment[3])
      edge:SetPoint(segment[1], parent, segment[1], 0, 0)
      edge:SetPoint(segment[2], parent, segment[2], 0, 0)
    end
  end
end

local function panel(parent, x, y, width, height, shade)
  local p = CreateFrame("Frame", nil, parent)
  p:SetSize(width, height)
  p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  paint(p, shade or {0.04, 0.08, 0.12, 0.94})
  border(p)
  return p
end

local function button(parent, title, x, y, width, height, handler, icon)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(width, height)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local texture = btn:CreateTexture(nil, "BACKGROUND")
  texture:SetAllPoints()
  texture:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\bronze-button")
  btn.background = texture
  local pad = icon and 37 or 8
  if icon then
    local img = btn:CreateTexture(nil, "ARTWORK")
    img:SetTexture(icon)
    img:SetSize(height - 9, height - 9)
    img:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.icon = img
  end
  btn.text = label(btn, "GameFontNormalSmall", width - pad - 4, height - 4, pad, -2)
  btn.text:SetText(title)
  btn:SetScript("OnClick", handler or function() end)
  return btn
end

local function setActive(btn, yes)
  if not btn then return end
  if yes then btn.background:SetVertexColor(1, 1, 1, 1)
  else btn.background:SetVertexColor(0.48, 0.68, 0.83, 0.9) end
end

local function inGameMap(mapID)
  if type(mapID) ~= "number" or not WorldMapFrame then return false end
  if type(WorldMapFrame.SetMapID) == "function" then
    local success = pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
    if not success then return false end
  end
  if type(WorldMapFrame.Show) == "function" then WorldMapFrame:Show(); return true end
  return false
end

local function waypoint()
  if not active then return end
  local wp = ns.browser.waypoint(active)
  if not wp then
    ns.commands.say("No sourced location available for this entry")
    return
  end
  if type(TomTom) ~= "table" or type(TomTom.AddWaypoint) ~= "function" then
    ns.commands.say("TomTom is not installed")
    return
  end
  local success = pcall(TomTom.AddWaypoint, TomTom, wp.mapID, wp.x, wp.y,
    {title = "Fishing Atlas: " .. wp.label, persistent = false})
  ns.commands.say(success and "TomTom waypoint created" or "TomTom rejected the waypoint")
end

local function updateFooter()
  local s = ns.storage.db and ns.storage.db.settings or {}
  if alertsButton then alertsButton.text:SetText("Alerts: " .. (s.notifications and "ON" or "OFF")) end
  if mapPinsButton then mapPinsButton.text:SetText("Map pins: " .. (s.mapPins and "ON" or "OFF")) end
end

local function zoneIcon(item)
  if item.kind == "zone" then return "Interface\\Icons\\INV_Misc_Map_01" end
  if item.kind == "vendor_reference" then return "Interface\\Icons\\INV_Misc_Bag_10" end
  if item.kind == "school_type" then return "Interface\\Icons\\Trade_Fishing" end
  return ns.browser.icon(item)
end

local function applyFilter(item)
  if UI.filterLocations and #ns.viewModel.mapPoints(item) == 0 then return false end
  if UI.filterFish and item.kind == "zone" then
    if #(ns.data.referenceZoneFish and ns.data.referenceZoneFish[item.id] or {}) == 0 then
      return false
    end
  end
  return true
end

local function findDefault(list)
  if #list == 0 then return nil end
  if UI.category == "zones" then
    for _, item in ipairs(list) do
      if item.name == "Ashenvale" then return item end
    end
  end
  return list[1]
end

local function tooltip(item, anchor)
  if not item or not GameTooltip then return end
  GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
  local kind, id = ns.browser.tooltip(item)
  local found = false
  if kind == "item" and type(GameTooltip.SetItemByID) == "function" then
    found = pcall(GameTooltip.SetItemByID, GameTooltip, id)
  elseif kind == "spell" and type(GameTooltip.SetSpellByID) == "function" then
    found = pcall(GameTooltip.SetSpellByID, GameTooltip, id)
  end
  if not found then GameTooltip:AddLine(item.name) end
  GameTooltip:AddLine("Evidence: " .. (item.confidence or "unknown"), 0.6, 0.85, 0.9)
  GameTooltip:Show()
end

local function renderMap()
  if not mapSurface then return end
  local mapID = ns.viewModel.mapID(active)
  ns.zoneMap.render(mapSurface, mapID, ns.viewModel.mapPoints(active))
  mapCaption:SetText(mapID and ("MAP " .. mapID .. " | pins are sourced observations")
    or "Select a zone or mapped vendor")
end

local function updateRight()
  if not zoneInfo then return end
  local item = active
  if not item then
    zoneInfo:SetText("Choose a fish, zone, recipe, vendor or school.")
    relatedTitle:SetText("RELATED REFERENCES")
    for _, btn in ipairs(rightRows) do btn:Hide() end
    renderMap()
    return
  end
  local info = ns.viewModel.summary(item)
  local textLines = {"Source: " .. tostring(info.source)}
  if info.skill then
    textLines[#textLines + 1] = "Minimum fishing skill: " .. info.skill
    textLines[#textLines + 1] = "Reliable catches: " .. tostring(info.reliable or "unknown")
  end
  textLines[#textLines + 1] = info.note or ""
  zoneInfo:SetText(table.concat(textLines, "\n"))
  local related
  if item.kind == "zone" then
    relatedTitle:SetText("VENDORS IN THIS ZONE")
    related = ns.viewModel.zoneVendors(item.id)
  elseif item.kind == "fish" then
    relatedTitle:SetText("REFERENCE ZONES")
    related = ns.viewModel.fishZones(item.id)
  else
    relatedTitle:SetText("RELATED INFORMATION")
    related = {}
  end
  for i, btn in ipairs(rightRows) do
    local record = related[i]
    if record then
      btn.text:SetText(record.name:sub(1, 33))
      btn:SetScript("OnClick", function()
        if item.kind == "zone" then UI.selectCategory("vendors", record.id)
        elseif item.kind == "fish" then UI.selectCategory("zones", record.mapID) end
      end)
      btn:Show()
    else
      btn:Hide()
    end
  end
  renderMap()
end

local function renderDetails()
  if not detailsScroll then return end
  local summary = ns.viewModel.summary(active)
  headerName:SetText(active and active.name or "Choose a record")
  headerMeta:SetText((summary.subtitle or "") .. "  |  " .. tostring(summary.source))
  for i, tab in ipairs(subTabs) do
    local heading = ns.viewModel.tabs(active)[i]
    if heading then
      tab.text:SetText(heading)
      tab:Show()
      setActive(tab, heading == UI.detailsTab)
      tab:SetScript("OnClick", function()
        UI.detailsTab = heading
        renderDetails()
      end)
    else tab:Hide() end
  end
  details = ns.viewModel.section(active, UI.detailsTab)
  local fullHeight = math.max(296, #details * 50 + 12)
  detailsChild:SetHeight(fullHeight)
  for i, item in ipairs(details) do
    local card = detailRows[i]
    if not card then
      card = CreateFrame("Frame", nil, detailsChild)
      card:SetSize(375, 47)
      local bg = paint(card, {0.06, 0.15, 0.19, 0.82})
      bg:SetVertexColor(0.06, 0.14, 0.18, 0.84)
      card.icon = card:CreateTexture(nil, "ARTWORK")
      card.icon:SetSize(32, 32)
      card.icon:SetPoint("LEFT", card, "LEFT", 7, 0)
      card.title = label(card, "GameFontNormal", 325, 20, 45, -4)
      card.detail = label(card, "GameFontHighlightSmall", 325, 17, 45, -26)
      detailRows[i] = card
    end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", detailsChild, "TOPLEFT", 0, -(i - 1) * 50)
    card.title:SetText(item.title)
    card.detail:SetText(item.detail)
    card.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    card:Show()
  end
  for i = #details + 1, #detailRows do detailRows[i]:Hide() end
  detailsScroll:SetVerticalScroll(0)
  updateRight()
end

local function select(item)
  active = item
  UI.detailsTab = "Overview"
  renderDetails()
  UI.draw()
end

function UI.scroll(amount)
  UI.offset = math.max(0, math.min(math.max(0, #results - visibleRows), UI.offset - amount))
  UI.draw()
end

function UI.draw()
  if not frame or uiBusy then return end
  uiBusy = true
  listCount:SetText(UI.category:upper() .. " (" .. #results .. ")")
  for i, btn in ipairs(rows) do
    local item = results[UI.offset + i]
    btn.item = item
    if item then
      btn.text:SetText(item.name:sub(1, 29))
      btn.icon:SetTexture(zoneIcon(item))
      btn.level:SetText("")
      if item.kind == "zone" then
        local skill = ns.data.zoneFishingSkill and ns.data.zoneFishingSkill[item.id]
        btn.level:SetText(skill and ("Lv " .. skill.minimum) or "?")
      end
      setActive(btn, item == active)
      btn:Show()
    else btn:Hide() end
  end
  listSlider:SetMinMaxValues(0, math.max(0, #results - visibleRows))
  listSlider:SetValue(UI.offset)
  listSlider:SetShown(#results > visibleRows)
  for _, btn in ipairs(sidebar) do
    btn.text:SetText(btn.caption .. "  (" .. btn.count .. ")")
    setActive(btn, btn.category == UI.category)
  end
  for _, btn in ipairs(tabs) do
    setActive(btn, btn.caption == UI.topPage)
  end
  updateFooter()
  uiBusy = false
end

function UI.refresh(reset)
  if not frame then return end
  local raw = ns.browser.list(UI.category, UI.query)
  results = {}
  for _, item in ipairs(raw) do
    if applyFilter(item) then results[#results + 1] = item end
  end
  if reset then UI.offset = 0 end
  if active then
    local matched
    for _, item in ipairs(results) do
      if item.id == active.id and item.kind == active.kind then matched = item; break end
    end
    active = matched
  end
  if not active then
    active = findDefault(results)
    UI.detailsTab = "Overview"
  end
  UI.draw()
  renderDetails()
end

function UI.selectCategory(category, id, topPage)
  UI.category, UI.offset, UI.query, UI.filterFish, UI.filterLocations = category, 0, "", false, false
  UI.topPage = topPage or "Explorer"
  search:SetText("")
  active = nil
  UI.refresh(true)
  if id then
    for _, item in ipairs(results) do
      if item.id == id then select(item); break end
    end
  end
end

local function fitFrame()
  if not frame then return end
  local sw = UIParent:GetWidth() or W
  local sh = UIParent:GetHeight() or H
  local scale = math.min(1, (sw - 28) / W, (sh - 25) / H)
  frame:SetScale(math.max(0.55, scale))
end

local function build()
  if frame or type(CreateFrame) ~= "function" or not UIParent then return end
  frame = CreateFrame("Frame", "FishingAtlasExplorer", UIParent)
  frame:SetSize(W, H)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\deepwater-background")
  bg:SetVertexColor(0.8, 0.86, 0.91, 1)
  border(frame)
  local banner = frame:CreateTexture(nil, "BORDER")
  banner:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  banner:SetSize(W, 90)
  banner:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\lakeshore-banner")
  banner:SetVertexColor(1, 1, 1, 0.9)
  local emblem = frame:CreateTexture(nil, "ARTWORK")
  emblem:SetSize(81, 81)
  emblem:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -3)
  emblem:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\atlas-emblem")
  label(frame, "GameFontNormalHuge", 665, 42, 105, -7):SetText("Fishing Atlas")
  label(frame, "GameFontHighlight", 670, 25, 108, -51):SetText("The Azeroth Fishing Compendium")
  versionLabel = label(frame, "GameFontHighlightSmall", 267, 30, 851, -21)
  versionLabel:SetText("v0.99.5  |  Data: mixed-source")
  button(frame, "X", 1167, -10, 30, 31, function() frame:Hide() end)
  button(frame, "?", 1132, -10, 30, 31, function()
    if ns.issues then ns.issues.open() end
  end)
  for i, title in ipairs(topTabs) do
    local itemCategory = categoryFor[title]
    local icon
    for _, definition in ipairs(categories) do
      if definition[1] == itemCategory then icon = definition[3]; break end
    end
    local btn = button(frame, title, 15 + (i - 1) * 169, -101, 163, 51, function()
      UI.selectCategory(itemCategory, nil, title)
    end, icon)
    btn.caption, btn.category = title, itemCategory
    tabs[#tabs + 1] = btn
  end
  local left = panel(frame, 13, -167, 194, 523, {0.025, 0.06, 0.08, 0.96})
  label(left, "GameFontNormal", 165, 24, 12, -8):SetText("SEARCH ATLAS")
  search = CreateFrame("EditBox", nil, left, "InputBoxTemplate")
  search:SetSize(170, 24)
  search:SetPoint("TOPLEFT", left, "TOPLEFT", 15, -38)
  search:SetAutoFocus(false)
  search:SetMaxLetters(70)
  search:SetScript("OnTextChanged", function(self)
    UI.query = self:GetText() or ""
    UI.offset, active = 0, nil
    UI.refresh(true)
  end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local counts = ns.viewModel.counts()
  for i, definition in ipairs(categories) do
    local key, text, icon = definition[1], definition[2], definition[3]
    local btn = button(left, text, 9, -78 - (i - 1) * 44, 176, 40, function()
      UI.selectCategory(key)
    end, icon)
    btn.category, btn.caption, btn.count = key, text, counts[key] or 0
    sidebar[#sidebar + 1] = btn
  end
  label(left, "GameFontNormal", 170, 22, 13, -394):SetText("QUICK FILTERS")
  local filterOne = button(left, "", 10, -421, 173, 28, function()
    UI.filterFish = not UI.filterFish
    UI.refresh(true)
  end)
  local filterTwo = button(left, "", 10, -454, 173, 28, function()
    UI.filterLocations = not UI.filterLocations
    UI.refresh(true)
  end)
  local function filters()
    filterOne.text:SetText((UI.filterFish and "[x]" or "[ ]") .. " Zones with fish")
    filterTwo.text:SetText((UI.filterLocations and "[x]" or "[ ]") .. " Mapped locations")
  end
  filterOne:SetScript("OnClick", function() UI.filterFish = not UI.filterFish
    filters(); UI.refresh(true) end)
  filterTwo:SetScript("OnClick", function() UI.filterLocations = not UI.filterLocations
    filters(); UI.refresh(true) end)
  filters()
  label(left, "GameFontHighlightSmall", 178, 25, 12, -492):SetText("Sources labeled | not all live verified")

  local listPanel = panel(frame, 216, -167, 265, 523)
  listCount = label(listPanel, "GameFontNormalLarge", 237, 25, 11, -9)
  listRegion = CreateFrame("Frame", nil, listPanel)
  listRegion:SetSize(232, 434)
  listRegion:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 9, -45)
  listRegion:EnableMouseWheel(true)
  listRegion:SetScript("OnMouseWheel", function(_, amount) UI.scroll(amount * 3) end)
  for i = 1, visibleRows do
    local btn = button(listRegion, "", 0, -(i - 1) * rowHeight, 227, 31,
      function() end, "Interface\\Icons\\INV_Misc_Map_01")
    btn.text:ClearAllPoints()
    btn.text:SetPoint("LEFT", btn, "LEFT", 38, 0)
    btn.text:SetSize(158, 26)
    btn.level = label(btn, "GameFontHighlightSmall", 34, 22, 190, -5)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mouse)
      if self.item then
        if mouse == "RightButton" then
          select(self.item)
          waypoint()
        else select(self.item) end
      end
    end)
    btn:SetScript("OnEnter", function(self) tooltip(self.item, self) end)
    btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    rows[i] = btn
  end
  listSlider = CreateFrame("Slider", nil, listPanel)
  listSlider:SetOrientation("VERTICAL")
  listSlider:SetSize(14, 407)
  listSlider:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -7, -54)
  listSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  listSlider:SetValueStep(1)
  listSlider:SetScript("OnValueChanged", function(_, value)
    local offset = math.floor(value + 0.5)
    if not uiBusy and offset ~= UI.offset then
      UI.offset = offset
      UI.draw()
    end
  end)
  label(listPanel, "GameFontHighlightSmall", 232, 19, 11, -492):SetText("Mouse wheel | Right click: TomTom")

  local middle = panel(frame, 489, -167, 407, 523)
  local header = panel(middle, 6, -6, 395, 110)
  local hero = header:CreateTexture(nil, "BACKGROUND")
  hero:SetAllPoints()
  hero:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\lakeshore-banner")
  hero:SetVertexColor(0.64, 0.77, 0.85, 0.67)
  headerName = label(header, "GameFontNormalLarge", 368, 33, 13, -13)
  headerMeta = label(header, "GameFontHighlight", 373, 30, 13, -53)
  for i = 1, 5 do
    local tab = button(middle, "", 6 + (i - 1) * 79, -128, 77, 32)
    subTabs[i] = tab
  end
  local detailPanel = panel(middle, 6, -171, 395, 344)
  detailsScroll = CreateFrame("ScrollFrame", nil, detailPanel, "UIPanelScrollFrameTemplate")
  detailsScroll:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 5, -7)
  detailsScroll:SetPoint("BOTTOMRIGHT", detailPanel, "BOTTOMRIGHT", -27, 8)
  detailsChild = CreateFrame("Frame", nil, detailsScroll)
  detailsChild:SetSize(375, 300)
  detailsScroll:SetScrollChild(detailsChild)

  local right = panel(frame, 904, -167, 293, 523)
  label(right, "GameFontNormal", 263, 24, 12, -8):SetText("ZONE MAP  |  Map art from game")
  mapSurface = panel(right, 9, -37, 275, 195)
  mapCaption = label(right, "GameFontHighlightSmall", 267, 19, 14, -237)
  button(right, "World Map", 156, -263, 126, 27, function()
    local id = ns.viewModel.mapID(active)
    if not inGameMap(id) then ns.commands.say("World map unavailable") end
  end)
  button(right, "TomTom", 9, -263, 136, 27, waypoint)
  local info = panel(right, 9, -304, 275, 92)
  label(info, "GameFontNormal", 252, 23, 10, -6):SetText("ZONE / ITEM INFO")
  zoneInfo = label(info, "GameFontHighlightSmall", 252, 61, 10, -29)
  zoneInfo:SetJustifyV("TOP")
  local related = panel(right, 9, -405, 275, 108)
  relatedTitle = label(related, "GameFontNormal", 260, 23, 10, -6)
  for i = 1, 3 do
    rightRows[i] = button(related, "", 9, -30 - (i - 1) * 25, 255, 24,
      function() end)
  end

  local footer = panel(frame, 13, -699, 1184, 44)
  label(footer, "GameFontNormal", 80, 30, 10, -8):SetText("ALERTS")
  alertsButton = button(footer, "Alerts", 91, -6, 132, 30, function()
    local s = ns.storage.db and ns.storage.db.settings
    if s then s.notifications = not s.notifications; updateFooter() end
  end)
  mapPinsButton = button(footer, "Pins", 229, -6, 140, 30, function()
    local s = ns.storage.db and ns.storage.db.settings
    if s then
      s.mapPins = not s.mapPins
      if ns.mapPins then ns.mapPins.refresh() end
      updateFooter()
    end
  end)
  button(footer, "Options", 383, -6, 120, 30, function()
    if ns.options then ns.options.open() end
  end)
  button(footer, "Refresh", 510, -6, 118, 30, function() UI.refresh(false) end)
  button(footer, "Report issue on GitHub", 642, -6, 237, 30, function()
    if ns.issues then ns.issues.open() end
  end)
  footerStatus = label(footer, "GameFontHighlightSmall", 260, 30, 895, -7)
  footerStatus:SetText("Data sources: client + reference + yours")
  frame:Hide()
  fitFrame()
end

function UI.show()
  build()
  if not frame then return false end
  fitFrame()
  frame:Show()
  UI.refresh(false)
  return true
end

function UI.toggle()
  build()
  if not frame then return false end
  if frame:IsShown() then frame:Hide() else UI.show() end
  return true
end
