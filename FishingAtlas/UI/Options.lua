-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native Settings > AddOns category with a legacy fallback.
local _, ns = ...
ns.options = {}
local O = ns.options
local panel, category

local function checkbox(parent, y, text, key, onChanged)
  local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
  local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("LEFT", button, "RIGHT", 6, 0)
  label:SetText(text)
  button:SetScript("OnShow", function(self)
    self:SetChecked(ns.storage.db and ns.storage.db.settings[key] == true)
  end)
  button:SetScript("OnClick", function(self)
    if not ns.storage.db then return end
    ns.storage.db.settings[key] = self:GetChecked() and true or false
    if onChanged then onChanged() end
  end)
  return button
end

function O.start()
  if panel or type(CreateFrame) ~= "function" then return end
  panel = CreateFrame("Frame", "FishingAtlasOptionsPanel")
  panel.name = "Fishing Atlas"
  local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -22)
  heading:SetText("Fishing Atlas | Preferences")
  local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -12)
  description:SetText("Saved fishing positions are historical observations, not active school spawns.")
  checkbox(panel, -88, "Show minimap launcher", "showMinimap", function()
    if ns.minimap then ns.minimap.update() end
  end)
  checkbox(panel, -125, "Show saved positions on the world map", "mapPins", function()
    if ns.mapPins then ns.mapPins.refresh() end
  end)
  checkbox(panel, -162, "Alert near saved fishing positions", "notifications")
  local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -209)
  note:SetWidth(520)
  note:SetJustifyH("LEFT")
  note:SetText("Use /fa radius 0.1-5 to change the map-relative alert radius.\n" ..
    "Use /fa fishing on|off to control the manual Space-key override.\n" ..
    "Database: client build 70888; current client may be newer.")
  if type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function"
      and type(Settings.RegisterAddOnCategory) == "function" then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
  elseif type(InterfaceOptions_AddCategory) == "function" then
    InterfaceOptions_AddCategory(panel)
  end
end

function O.open()
  if not panel then O.start() end
  if category and type(Settings) == "table" and type(Settings.OpenToCategory) == "function" then
    local id = type(category.GetID) == "function" and category:GetID() or panel.name
    Settings.OpenToCategory(id)
    return true
  elseif type(InterfaceOptionsFrame_OpenToCategory) == "function" then
    InterfaceOptionsFrame_OpenToCategory(panel)
    return true
  end
  return false
end
