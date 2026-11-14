-- SPDX-License-Identifier: GPL-3.0-or-later
-- Fishing Atlas 0.99.6: image-3-inspired three-column explorer.
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
  {"schools", "Schools", "Interface\\Icons\\INV_Misc_Fish_02"},
  {"vendors", "Vendors", "Interface\\Icons\\INV_Misc_Bag_10"},
  {"gear", "Gear", "Interface\\Icons\\Trade_Fishing"},
  {"journal", "Journal", "Interface\\Icons\\INV_Misc_Book_09"}
}
local topTabs = {"Explorer", "Items", "Journal", "Recipes", "Zones", "Schools", "Vendors", "Gear"}
local categoryFor = {Explorer = "zones", Items = "items", Journal = "journal", Recipes = "recipes",
  Zones = "zones", Schools = "schools", Vendors = "vendors", Gear = "gear"}
UI.category, UI.query, UI.offset = "zones", "", 0
UI.topPage = "Explorer"
UI.filterFish, UI.filterLocations, UI.detailsTab = false, false, "Overview"
UI.recipeFilter = "all"
UI.searchAll = true
local frame, search, listCount, listSlider, listRegion, headerName, headerMeta
local detailsScroll, detailsChild, mapSurface, mapCaption, zoneInfo, relatedTitle
local active, rows, sidebar, tabs, subTabs, detailRows, rightRows = nil, {}, {}, {}, {}, {}, {}
local results, details = {}, {}
local alertsButton, mapPinsButton, footerStatus, versionLabel, context, contextButtons
local filterOne, filterTwo, searchScopeButton
local uiBusy = false
UI.mapOverride, UI.selectedPoint = nil, nil
local sourcePopup, sourceField, sourceCaption
local renderDetails

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
  local pad = icon and (height + 6) or 8
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
  -- Opening the world map must work even for records with no sourced zone.
  -- In that case show the player's current map rather than claiming there is
  -- a verified location for an otherwise unmapped fish/recipe.
  if type(OpenWorldMap) == "function" then
    local ok = pcall(OpenWorldMap, mapID)
    if ok and WorldMapFrame and WorldMapFrame.IsShown
        and WorldMapFrame:IsShown() then return true end
  end
  local map = WorldMapFrame
  if not map and type(C_AddOns) == "table" and type(C_AddOns.LoadAddOn) == "function" then
    pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap")
    map = WorldMapFrame
  end
  if not map and type(UIParentLoadAddOn) == "function" then
    pcall(UIParentLoadAddOn, "Blizzard_WorldMap")
    map = WorldMapFrame
  end
  if map and type(map.Show) == "function" then
    pcall(map.Show, map)
  elseif type(ToggleWorldMap) == "function" then
    pcall(ToggleWorldMap)
    map = WorldMapFrame
  end
  if map and type(map.IsShown) == "function" and map:IsShown() then
    if type(mapID) == "number" and type(map.SetMapID) == "function" then
      local ok, why = pcall(map.SetMapID, map, mapID)
      if not ok and ns.commands then
        ns.commands.say("Map opened, but zone " .. mapID ..
          " could not be selected: " .. tostring(why))
      end
    end
    return true
  end
  return false
end
UI.openWorldMap = inGameMap

local function waypoint()
  if not active then return end
  local wp = UI.selectedPoint or ns.browser.waypoint(active)
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

local function hideContext()
  if context then context:Hide() end
end

local function showContext(item)
  if not context or not item then return end
  active = item
  UI.detailsTab = "Overview"
  renderDetails()
  UI.draw()
  local wp = ns.browser.waypoint(item)
  contextButtons[2]:SetEnabled(wp ~= nil)
  contextButtons[2].text:SetText(wp and "TomTom waypoint" or "No mapped waypoint")
  local mapID = ns.viewModel.mapID(item)
  contextButtons[3]:SetEnabled(mapID ~= nil)
  context:Show()
end

local function updateFooter()
  local s = ns.storage.db and ns.storage.db.settings or {}
  if alertsButton then alertsButton.text:SetText("Alerts: " .. (s.notifications and "ON" or "OFF")) end
  if mapPinsButton then mapPinsButton.text:SetText("Map pins: " .. (s.mapPins and "ON" or "OFF")) end
end

local function zoneIcon(item)
  if item.kind == "zone" then return "Interface\\Icons\\INV_Misc_Map_01" end
  if item.kind == "vendor_reference" then return "Interface\\Icons\\INV_Misc_Bag_10" end
  if item.kind == "school_type" then return ns.browser.icon(item) end
  return ns.browser.icon(item)
end

local function applyFilter(item)
  if UI.category == "recipes" and UI.recipeFilter ~= "all" and ns.recipeKnowledge then
    local status = ns.recipeKnowledge.status(item.id)
    if UI.recipeFilter == "known" and status ~= "known" then return false end
    if UI.recipeFilter == "not_known" and status == "known" then return false end
  end
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
  if not found and kind and id and type(GameTooltip.SetHyperlink) == "function" then
    found = pcall(GameTooltip.SetHyperlink, GameTooltip, kind .. ":" .. id)
  end
  if not found then GameTooltip:AddLine(item.name) end
  GameTooltip:AddLine("Evidence: " .. (item.confidence or "unknown"), 0.6, 0.85, 0.9)
  GameTooltip:Show()
end

local function renderMap()
  if not mapSurface then return end
  local mapID = UI.mapOverride or ns.viewModel.mapID(active)
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
  elseif item.kind == "item" then
    relatedTitle:SetText("SELLERS / ACQUISITION")
    related = ns.viewModel.itemVendors(item.id)
  elseif item.kind == "school_type" then
    relatedTitle:SetText("OBSERVED ZONES")
    local points = ns.viewModel.mapPoints(item)
    related = {}
    local seen = {}
    for _, point in ipairs(points) do
      if not seen[point.mapID] then
        seen[point.mapID] = true
        related[#related + 1] = {name = "Map " .. point.mapID, mapID = point.mapID}
      end
    end
  else
    relatedTitle:SetText("RELATED INFORMATION")
    related = {}
  end
  for i, btn in ipairs(rightRows) do
    local record = related[i]
    if record then
      btn.record = record
      btn.text:SetText(record.name:sub(1, 33))
      btn:SetScript("OnClick", function()
        if item.kind == "zone" or item.kind == "item" then
          UI.selectCategory("vendors", record.id)
        elseif item.kind == "fish" then
          UI.selectCategory("zones", record.mapID)
        elseif item.kind == "school_type" then
          UI.mapOverride = record.mapID
          renderMap()
        end
      end)
      btn:Show()
    else
      btn:Hide()
    end
  end
  renderMap()
end

local function rowTooltip(record, owner)
  if not record or not GameTooltip then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local shown = false
  if record.itemId and type(GameTooltip.SetItemByID) == "function" then
    shown = pcall(GameTooltip.SetItemByID, GameTooltip, record.itemId)
  elseif record.spellId and type(GameTooltip.SetSpellByID) == "function" then
    shown = pcall(GameTooltip.SetSpellByID, GameTooltip, record.spellId)
  end
  if not shown and record.itemId and type(GameTooltip.SetHyperlink) == "function" then
    shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. record.itemId)
  end
  if not shown then GameTooltip:AddLine(record.title or "Fishing Atlas") end
  if record.detail and record.detail ~= "" then
    GameTooltip:AddLine(record.detail, 1, 1, 1, true)
  end
  GameTooltip:AddLine("Evidence: " .. tostring(record.confidence or "unknown"),
    0.6, 0.85, 0.9)
  if record.vendorId or record.mapID then
    GameTooltip:AddLine("Click to navigate", 0.3, 0.9, 0.65)
  end
  GameTooltip:Show()
end

local function rowClick(record)
  if not record then return end
  if record.toggleRecipe and ns.recipeKnowledge then
    ns.recipeKnowledge.cycle(record.recipeId)
    UI.refresh(false)
  elseif record.vendorId then
    UI.selectCategory("vendors", record.vendorId)
  elseif record.recipeId then
    UI.selectCategory("recipes", record.recipeId)
  elseif record.mapID then
    UI.mapOverride = record.mapID
    UI.selectedPoint = record.x and record.y and {mapID = record.mapID,
      x = record.x, y = record.y, label = record.title or "Fishing Atlas"} or nil
    renderMap()
    local opened = inGameMap(record.mapID)
    if not opened then ns.commands.say("World map could not be opened by this client") end
    if record.x and record.y and type(TomTom) == "table"
        and type(TomTom.AddWaypoint) == "function" then
      pcall(TomTom.AddWaypoint, TomTom, record.mapID, record.x, record.y,
        {title = "Fishing Atlas: " .. tostring(record.title), persistent = false})
    end
  elseif record.itemId then
    UI.openItem(record.itemId)
  end
end

renderDetails = function()
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
      card = CreateFrame("Button", nil, detailsChild)
      card:SetSize(375, 47)
      local bg = paint(card, {0.06, 0.15, 0.19, 0.82})
      bg:SetVertexColor(0.06, 0.14, 0.18, 0.84)
      card.icon = card:CreateTexture(nil, "ARTWORK")
      card.icon:SetSize(32, 32)
      card.icon:SetPoint("LEFT", card, "LEFT", 7, 0)
      card.title = label(card, "GameFontNormal", 325, 20, 45, -4)
      card.detail = label(card, "GameFontHighlightSmall", 325, 17, 45, -26)
      card:RegisterForClicks("LeftButtonUp")
      card:SetScript("OnEnter", function(self) rowTooltip(self.record, self) end)
      card:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
      end)
      card:SetScript("OnClick", function(self) rowClick(self.record) end)
      detailRows[i] = card
    end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", detailsChild, "TOPLEFT", 0, -(i - 1) * 50)
    card.record = item
    card.title:SetText(item.title)
    card.detail:SetText(item.detail)
    card.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_Note_01")
    card:Show()
  end
  for i = #details + 1, #detailRows do detailRows[i]:Hide() end
  detailsScroll:SetVerticalScroll(0)
  updateRight()
end

local function select(item)
  if item and item.atlasCategory and item.atlasCategory ~= UI.category then
    UI.selectCategory(item.atlasCategory, item.id)
    return
  end
  active = item
  UI.mapOverride, UI.selectedPoint = nil, nil
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
  local globalResults = UI.searchAll and #UI.query >= 2
  listCount:SetText((globalResults and "SEARCH" or UI.category:upper()) .. " (" .. #results .. ")")
  for i, btn in ipairs(rows) do
    local item = results[UI.offset + i]
    btn.item = item
    if item then
      local display = item.atlasCategory and ("[" .. item.atlasCategory .. "] " .. item.name)
        or item.name
      btn.text:SetText(display:sub(1, 29))
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
    if btn.category == "vendors" or btn.category == "recipes" or btn.category == "fish" then
      btn.count = #ns.browser.list(btn.category, "")
    end
    btn.text:SetText(btn.caption .. "  (" .. btn.count .. ")")
    setActive(btn, btn.category == UI.category)
  end
  for _, btn in ipairs(tabs) do
    setActive(btn, btn.caption == UI.topPage)
  end
  if searchScopeButton then
    searchScopeButton.text:SetText(UI.searchAll and "Global" or "This tab")
  end
  if filterOne and filterTwo then
    if UI.category == "recipes" then
      filterOne.text:SetText((UI.recipeFilter == "known" and "[x]" or "[ ]") .. " Known recipes")
      filterTwo.text:SetText((UI.recipeFilter == "not_known" and "[x]" or "[ ]") ..
        " Not known / unchecked")
    else
      filterOne.text:SetText((UI.filterFish and "[x]" or "[ ]") .. " Zones with fish")
      filterTwo.text:SetText((UI.filterLocations and "[x]" or "[ ]") .. " Mapped locations")
    end
  end
  updateFooter()
  uiBusy = false
end

function UI.refresh(reset)
  if not frame then return end
  local raw = UI.searchAll and #UI.query >= 2
    and ns.browser.searchAll(UI.query) or ns.browser.list(UI.category, UI.query)
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
  hideContext()
end

function UI.selectCategory(category, id, topPage)
  UI.mapOverride, UI.selectedPoint = nil, nil
  UI.category, UI.offset, UI.query, UI.filterFish, UI.filterLocations = category, 0, "", false, false
  UI.topPage = topPage or (category == "items" and "Items"
    or category == "recipes" and "Recipes" or category == "vendors" and "Vendors"
    or category == "schools" and "Schools" or category == "gear" and "Gear"
    or category == "zones" and "Zones" or "Explorer")
  search:SetText("")
  active = nil
  UI.refresh(true)
  if id then
    for _, item in ipairs(results) do
      if item.id == id then select(item); break end
    end
  end
end

function UI.openItem(id)
  if type(id) ~= "number" or id <= 0 then return end
  UI.selectCategory("items", id)
  if not active or active.id ~= id then
    active = {id = id, kind = "item", name = ns.catalog.name("item", id),
      confidence = "source_relationship"}
    UI.detailsTab = "Overview"
    renderDetails()
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
  -- Standard WoW Escape behavior, without consuming movement or chat keys.
  if type(UISpecialFrames) == "table" then
    local registered
    for _, frameName in ipairs(UISpecialFrames) do
      if frameName == "FishingAtlasExplorer" then registered = true; break end
    end
    if not registered then
      UISpecialFrames[#UISpecialFrames + 1] = "FishingAtlasExplorer"
    end
  end
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
  versionLabel:SetText("v0.99.6  |  Data: sourced + reference")
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
    if title == "Items" then icon = "Interface\\Icons\\INV_Misc_Bag_10" end
    local btn = button(frame, title, 15 + (i - 1) * 148, -101, 142, 51, function()
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
  search:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    if frame then frame:Hide() end
  end)
  searchScopeButton = button(left, "Global", 105, -7, 79, 27, function()
    UI.searchAll = not UI.searchAll
    UI.refresh(true)
  end)
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
  filterOne = button(left, "", 10, -421, 173, 28, function()
    UI.filterFish = not UI.filterFish
    UI.refresh(true)
  end)
  filterTwo = button(left, "", 10, -454, 173, 28, function()
    UI.filterLocations = not UI.filterLocations
    UI.refresh(true)
  end)
  local function filters()
    filterOne.text:SetText((UI.filterFish and "[x]" or "[ ]") .. " Zones with fish")
    filterTwo.text:SetText((UI.filterLocations and "[x]" or "[ ]") .. " Mapped locations")
  end
  filterOne:SetScript("OnClick", function()
    if UI.category == "recipes" then
      UI.recipeFilter = UI.recipeFilter == "known" and "all" or "known"
    else UI.filterFish = not UI.filterFish end
    if ns.storage.db and ns.storage.db.settings then
      ns.storage.db.settings.recipeFilter = UI.recipeFilter
    end
    UI.refresh(true)
  end)
  filterTwo:SetScript("OnClick", function()
    if UI.category == "recipes" then
      UI.recipeFilter = UI.recipeFilter == "not_known" and "all" or "not_known"
    else UI.filterLocations = not UI.filterLocations end
    if ns.storage.db and ns.storage.db.settings then
      ns.storage.db.settings.recipeFilter = UI.recipeFilter
    end
    UI.refresh(true)
  end)
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
        if mouse == "RightButton" then showContext(self.item)
        else hideContext(); select(self.item) end
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
    rightRows[i]:SetScript("OnEnter", function(self)
      if not GameTooltip or not self.record then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.record.name or "Source")
      GameTooltip:AddLine(self.record.confidence or
        self.record.evidence or "Source reference", 0.5, 0.9, 0.85)
      GameTooltip:AddLine("Click to navigate", 1, 1, 1)
      GameTooltip:Show()
    end)
    rightRows[i]:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
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
  button(footer, "Source link", 883, -6, 106, 30, function()
    if not sourcePopup then return end
    local url = ns.sources and ns.sources.linkFor(active) or nil
    if not url then url = "No documented upstream page for this record" end
    sourceField:SetText(url)
    sourceField:HighlightText()
    sourceField:SetFocus()
    local meta = ns.sources and ns.sources.metadata() or {}
    sourceCaption:SetText("Record source: " .. tostring(active and active.confidence or "unknown")
      .. " | Observed snapshot: " .. tostring(meta.dataAsOf or "Not imported")
      .. "\\n" .. (ns.sources and ns.sources.creditFor(active) or "No source metadata"))
    sourcePopup:Show()
  end)
  footerStatus = label(footer, "GameFontHighlightSmall", 180, 30, 999, -7)
  footerStatus:SetText("Client + references + yours")
  sourcePopup = panel(frame, 290, -272, 635, 175, {0.03, 0.10, 0.14, 0.99})
  sourcePopup:SetFrameStrata("TOOLTIP")
  label(sourcePopup, "GameFontNormal", 595, 25, 13, -10):SetText("SOURCE AND ATTRIBUTION")
  sourceCaption = label(sourcePopup, "GameFontHighlightSmall", 605, 49, 13, -40)
  sourceCaption:SetJustifyV("TOP")
  sourceField = CreateFrame("EditBox", nil, sourcePopup, "InputBoxTemplate")
  sourceField:SetSize(580, 25)
  sourceField:SetPoint("TOPLEFT", sourcePopup, "TOPLEFT", 20, -100)
  sourceField:SetAutoFocus(false)
  sourceField:SetScript("OnEscapePressed", function() sourcePopup:Hide() end)
  button(sourcePopup, "Close", 520, -134, 90, 29,
    function() sourcePopup:Hide() end)
  sourcePopup:Hide()
  context = panel(frame, 480, -345, 215, 150, {0.04, 0.10, 0.13, 0.99})
  context:SetFrameStrata("TOOLTIP")
  contextButtons = {
    button(context, "Inspect record", 7, -8, 200, 30, function()
      hideContext()
      renderDetails()
    end),
    button(context, "TomTom waypoint", 7, -43, 200, 30, function()
      hideContext()
      waypoint()
    end),
    button(context, "Open world map", 7, -78, 200, 30, function()
      local mapID = ns.viewModel.mapID(active)
      hideContext()
      if not inGameMap(mapID) then ns.commands.say("World map unavailable") end
    end),
    button(context, "Report issue", 7, -113, 200, 30, function()
      hideContext()
      if ns.issues then ns.issues.open() end
    end)
  }
  context:Hide()
  UI.recipeFilter = (ns.storage.db and ns.storage.db.settings
    and ns.storage.db.settings.recipeFilter) or "all"
  frame:Hide()
  fitFrame()
end

function UI.show()
  build()
  if not frame then return false end
  hideContext()
  fitFrame()
  frame:Show()
  if ns.recipeKnowledge then ns.recipeKnowledge.scanOpenProfession() end
  UI.refresh(false)
  return true
end

function UI.toggle()
  build()
  if not frame then return false end
  if frame:IsShown() then frame:Hide() else UI.show() end
  return true
end
