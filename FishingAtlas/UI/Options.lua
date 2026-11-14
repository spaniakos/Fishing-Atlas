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

local function action(parent, x, y, text, callback)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(104, 26)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  btn:SetText(text)
  btn:SetScript("OnClick", callback)
  return btn
end

local function note(parent, x, y, text)
  local display = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  display:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  display:SetWidth(540)
  display:SetJustifyH("LEFT")
  display:SetText(text)
  return display
end

function O.start()
  if panel or type(CreateFrame) ~= "function" then return end
  panel = CreateFrame("Frame", "FishingAtlasOptionsPanel")
  panel:SetSize(680, 610)
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
  local radiusText = note(panel, 20, -206, "")
  local function updateRadius()
    local settings = ns.storage.db and ns.storage.db.settings or {}
    radiusText:SetText(string.format("Alert radius: %.1f%% of local map (0.1 to 5.0)",
      settings.radiusPercent or 1))
  end
  action(panel, 20, -232, "Radius -", function()
    local settings = ns.storage.db and ns.storage.db.settings
    if settings then
      settings.radiusPercent = math.max(0.1, math.floor((settings.radiusPercent - 0.1) * 10 + 0.5) / 10)
      updateRadius()
    end
  end)
  action(panel, 137, -232, "Radius +", function()
    local settings = ns.storage.db and ns.storage.db.settings
    if settings then
      settings.radiusPercent = math.min(5, math.floor((settings.radiusPercent + 0.1) * 10 + 0.5) / 10)
      updateRadius()
    end
  end)
  updateRadius()

  local fishingMode = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  fishingMode:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -274)
  local castLabel = note(panel, 54, -276, "Use Space to manually cast Fishing (out of combat only)")
  fishingMode:SetScript("OnShow", function(self)
    self:SetChecked(ns.fishing and ns.fishing.isEnabled() or false)
  end)
  fishingMode:SetScript("OnClick", function(self)
    local ok, status = ns.fishing.setEnabled(self:GetChecked())
    if not ok then self:SetChecked(ns.fishing.isEnabled()) end
    if ns.commands then ns.commands.say(status) end
  end)

  local gearText = note(panel, 20, -321, "")
  local function updateGear()
    local profile = ns.gear.profile()
    local pole = profile.fishing_pole and ns.catalog.name("item", profile.fishing_pole)
      or "None"
    local lure = profile.lure and ns.catalog.name("item", profile.lure) or "None"
    gearText:SetText("Preferred pole: " .. pole .. "\nPreferred lure: " .. lure)
  end
  local function cycle(kind)
    local entries = ns.catalog.byCategory(kind, 100)
    if #entries == 0 then return end
    local selected = ns.gear.profile()[kind]
    local nextIndex = 1
    for i, item in ipairs(entries) do
      if item.id == selected then nextIndex = i % #entries + 1; break end
    end
    local ok, message = ns.gear.set(kind, entries[nextIndex].id)
    if not ok and ns.commands then ns.commands.say(message) end
    updateGear()
  end
  action(panel, 20, -370, "Next pole", function() cycle("fishing_pole") end)
  action(panel, 137, -370, "Next lure", function() cycle("lure") end)
  updateGear()

  local angleText = note(panel, 20, -408, "")
  local function updateAngle()
    local settings = ns.storage.db and ns.storage.db.settings or {}
    angleText:SetText("Minimap launcher angle: " ..
      tostring(math.floor((settings.minimapAngle or 210) % 360)) .. " degrees")
  end
  action(panel, 20, -434, "Rotate left", function()
    local settings = ns.storage.db and ns.storage.db.settings
    if settings then
      settings.minimapAngle = ((settings.minimapAngle or 210) + 15) % 360
      if ns.minimap then ns.minimap.update() end
      updateAngle()
    end
  end)
  action(panel, 137, -434, "Rotate right", function()
    local settings = ns.storage.db and ns.storage.db.settings
    if settings then
      settings.minimapAngle = ((settings.minimapAngle or 210) - 15) % 360
      if ns.minimap then ns.minimap.update() end
      updateAngle()
    end
  end)
  updateAngle()

  local filterText = note(panel, 20, -476, "")
  local function updateRecipeFilter()
    local settings = ns.storage.db and ns.storage.db.settings or {}
    filterText:SetText("Recipe filter: " .. tostring(settings.recipeFilter or "all"))
  end
  action(panel, 20, -502, "Cycle filter", function()
    local settings = ns.storage.db and ns.storage.db.settings
    if not settings then return end
    local current = settings.recipeFilter or "all"
    settings.recipeFilter = current == "all" and "known"
      or current == "known" and "not_known" or "all"
    updateRecipeFilter()
    if ns.ui then ns.ui.recipeFilter = settings.recipeFilter; ns.ui.refresh(true) end
  end)
  updateRecipeFilter()
  note(panel, 20, -549, "Recipe overrides are character-specific; open a recipe to mark it known, not learned, or unchecked. Other settings are account-wide.")
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
