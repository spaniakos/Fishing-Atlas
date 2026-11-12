-- SPDX-License-Identifier: GPL-3.0-or-later
-- Basic FrameXML explorer; built only on demand to avoid login/UI conflicts.
local _, ns = ...
ns.ui = {}
local UI = ns.ui
local categories = {"fish", "gear", "recipes", "zones", "journal", "schools", "vendors"}
local pageSize = 10
UI.category, UI.query, UI.page = "fish", "", 1
local frame, search, summary, details
local rows, tabButtons = {}, {}

local function font(parent, x, y, width, height, size)
  local label = parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  label:SetSize(width, height)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("MIDDLE")
  return label
end

local function control(parent, title, w, h, x, y, click)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(w, h)
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.16, 0.26, 0.31, 0.95)
  button.title = font(button, 8, -2, w - 12, h - 4, "GameFontNormalSmall")
  button.title:SetText(title)
  button:SetScript("OnClick", click)
  return button
end

function UI.refresh()
  if not frame then return end
  local data = ns.browser.list(UI.category, UI.query)
  local pages = math.max(1, math.ceil(#data / pageSize))
  UI.page = math.min(UI.page, pages)
  summary:SetText(UI.category .. ": " .. #data .. " entries, page " .. UI.page .. "/" .. pages)
  for i, btn in ipairs(rows) do
    local item = data[(UI.page - 1) * pageSize + i]
    if item then
      btn.title:SetText(item.name:sub(1, 45) .. "  [" .. tostring(item.id) .. "]")
      btn:SetScript("OnClick", function()
        details:SetText(table.concat(ns.browser.details(item), "\n"))
      end)
      btn:Show()
    else
      btn:Hide()
    end
  end
  for _, btn in ipairs(tabButtons) do
    btn.title:SetText((btn.category == UI.category and "> " or "") .. btn.category)
  end
end

local function build()
  if frame or type(CreateFrame) ~= "function" or not UIParent then return end
  frame = CreateFrame("Frame", "FishingAtlasExplorer", UIParent)
  frame:SetSize(660, 670)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.035, 0.065, 0.075, 0.96)
  local heading = font(frame, 18, -12, 550, 25, "GameFontNormalLarge")
  heading:SetText("Fishing Atlas  |  WoW Forever 70888")
  control(frame, "X", 32, 28, 609, -12, function() frame:Hide() end)
  for i, category in ipairs(categories) do
    local btn = control(frame, category, 85, 29, 17 + (i - 1) * 90, -53, function()
      UI.category, UI.page = category, 1
      UI.refresh()
    end)
    btn.category = category
    tabButtons[#tabButtons + 1] = btn
  end
  local prompt = font(frame, 18, -94, 80, 28, "GameFontNormalSmall")
  prompt:SetText("Search:")
  search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  search:SetSize(450, 25)
  search:SetPoint("TOPLEFT", frame, "TOPLEFT", 91, -97)
  search:SetAutoFocus(false)
  search:SetMaxLetters(60)
  search:SetScript("OnTextChanged", function(self)
    UI.query, UI.page = self:GetText() or "", 1
    UI.refresh()
  end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  summary = font(frame, 18, -133, 590, 25, "GameFontNormal")
  for i = 1, pageSize do
    rows[i] = control(frame, "", 623, 25, 19, -167 - (i - 1) * 27, function() end)
  end
  control(frame, "< Prev", 92, 27, 19, -443, function()
    UI.page = math.max(1, UI.page - 1); UI.refresh()
  end)
  control(frame, "Next >", 92, 27, 116, -443, function()
    UI.page = UI.page + 1; UI.refresh()
  end)
  local toggle = control(frame, "Alerts", 90, 27, 551, -443, function()
    if ns.storage.db and ns.storage.db.settings then
      local settings = ns.storage.db.settings
      settings.notifications = not settings.notifications
      ns.commands.say("Proximity alerts " .. (settings.notifications and "on" or "off"))
    end
  end)
  toggle:Show()
  details = font(frame, 20, -486, 615, 160, "GameFontHighlightSmall")
  details:SetJustifyV("TOP")
  details:SetText("Select an entry for details. Unverified data is labeled.")
  frame:Hide()
end

function UI.show()
  build()
  if not frame then return false end
  frame:Show()
  UI.refresh()
  return true
end

function UI.toggle()
  build()
  if not frame then return false end
  if frame:IsShown() then frame:Hide() else UI.show() end
  return true
end
