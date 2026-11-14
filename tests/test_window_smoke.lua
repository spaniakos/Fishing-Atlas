-- SPDX-License-Identifier: GPL-3.0-or-later
-- Mock enough FrameXML to catch nil callbacks/layout wiring before client tests.
local created = {}
local function element()
  local f = {shown = true, width = 0, height = 0, scripts = {}, text = ""}
  local methods = {
    "SetPoint", "ClearAllPoints", "SetTexture", "SetVertexColor", "SetAllPoints",
    "SetFrameStrata", "SetMovable", "EnableMouse", "EnableMouseWheel", "RegisterForDrag", "StartMoving",
    "StopMovingOrSizing", "SetJustifyH", "SetJustifyV", "SetSize", "SetWordWrap",
    "RegisterForClicks", "SetMinMaxValues", "SetValueStep", "SetOrientation",
    "SetThumbTexture", "SetVerticalScroll", "SetText", "SetAutoFocus",
    "SetMaxLetters", "SetFocus", "ClearFocus", "SetEnabled", "SetScale"
  }
  for _, method in ipairs(methods) do
    f[method] = function(self, ...) if method == "SetText" then self.text = (...) end end
  end
  f.SetSize = function(self, w, h) self.width, self.height = w, h end
  f.GetWidth = function(self) return self.width end
  f.GetHeight = function(self) return self.height end
  f.GetStringHeight = function() return 20 end
  f.SetHeight = function(self, h) self.height = h end
  f.SetWidth = function(self, w) self.width = w end
  f.SetValue = function(self, n)
    self.value = n
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, n) end
  end
  f.SetText = function(self, value)
    self.text = value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
  end
  f.SetScript = function(self, k, callback) self.scripts[k] = callback end
  f.Show = function(self) self.shown = true end
  f.Hide = function(self) self.shown = false end
  f.IsShown = function(self) return self.shown end
  f.SetShown = function(self, v) self.shown = v end
  f.CreateTexture = function() return element() end
  f.CreateFontString = function() return element() end
  f.GetText = function(self) return self.text end
  f.SetScrollChild = function(self, child) self.child = child end
  return f
end
CreateFrame = function(kind)
  local frame = element()
  frame.kind = kind
  created[#created + 1] = frame
  return frame
end
UIParent = element()
UIParent:SetSize(1400, 860)
local ns = {
  storage = {db = {settings = {notifications = true, mapPins = true}}},
  catalog = {name = function(_, id) return "Fish " .. id end,
    icon = function() return "Icon" end,
    entity = function(_, id)
      if id == 12 or id == 13 then return {category = "fish"} end
    end},
  data = {zoneFishingSkill = {[1440] = {minimum = 55, reliable = 150}},
    referenceZoneFish = {[1440] = {{id = 12}}}},
  browser = {},
  viewModel = {},
  zoneMap = {render = function() return true end},
  issues = {open = function() return true end},
  options = {open = function() return true end},
  commands = {say = function() end},
  mapPins = {refresh = function() end}
}
local zone = {id = 1440, kind = "zone", name = "Ashenvale", confidence = "verified_client"}
local fish = {id = 12, kind = "fish", name = "Darkclaw Lobster", confidence = "reference"}
local otherFish = {id = 13, kind = "fish", name = "Raw Nightfin Snapper", confidence = "reference"}
ns.browser.list = function(category)
  if category == "zones" then return {zone} end
  if category == "fish" then return {fish, otherFish} end
  return {}
end
ns.browser.searchAll = function(query)
  if query == "night" then
    return {{id = 13, kind = "fish", name = "Raw Nightfin Snapper",
      atlasCategory = "fish", confidence = "reference"}}
  elseif query == "pole" then
    return {{id = 6256, kind = "fishing_pole", name = "Fishing Pole",
      atlasCategory = "gear", confidence = "reference"}}
  elseif query == "lobster" then
    return {{id = 12, kind = "fish", name = "Darkclaw Lobster",
      atlasCategory = "fish", confidence = "reference"}}
  end
  return {}
end
ns.browser.icon = function() return "Icon" end
ns.browser.tooltip = function() return nil end
ns.browser.waypoint = function() return nil end
ns.viewModel.counts = function() return {zones = 1, fish = 1} end
ns.viewModel.tabs = function() return {"Overview", "Fish"} end
ns.viewModel.section = function() return {{title = "Fishing skill", detail = "55 minimum"}} end
ns.viewModel.summary = function() return {subtitle = "ZONE", source = "client_reference",
  note = "Reference only", skill = 55, reliable = 150} end
ns.viewModel.zoneVendors = function() return {} end
ns.viewModel.itemVendors = function() return {} end
ns.viewModel.fishZones = function() return {} end
ns.viewModel.mapID = function(item) return item and item.kind == "zone" and item.id or nil end
ns.viewModel.mapPoints = function() return {} end
assert(loadfile("FishingAtlas/UI/Window.lua"))("FishingAtlas", ns)
assert(ns.ui.toggle())
assert(ns.ui.category == "zones")
assert(ns.ui.selectCategory("fish") == nil)
assert(ns.ui.category == "fish")
ns.ui.selectCategory("fish", 13)
assert(ns.ui.selected().id == 13, "Fish click-by-ID must not always select Darkclaw Lobster")
ns.ui.openItem(12)
assert(ns.ui.category == "fish" and ns.ui.selected().id == 12,
  "Known fish item should open in the Fish inspector")
ns.ui.selectCategory("fish", 99999)
assert(ns.ui.selected().id == 99999, "Unindexed fish must not fall back to first list entry")
-- Global results may not exist in a freshly opened destination index.
-- The exact selected record must survive even then, across every category.
for _, category in ipairs({"gear", "items", "recipes", "vendors", "schools"}) do
  local record = {id = 998877, name = "Exact search hit",
    kind = category == "gear" and "fishing_pole"
      or category == "recipes" and "Cooking"
      or category == "vendors" and "vendor_reference"
      or category == "schools" and "school_type" or "item",
    confidence = "reference", atlasCategory = category}
  ns.ui.selectCategory(category, record.id, nil, record)
  assert(ns.ui.selected().id == record.id and
    ns.ui.selected().name == "Exact search hit",
    "Global search must never land on category[1]: " .. category)
end
-- Reproduce the player's real flow rather than calling selectCategory:
-- typing -> OnTextChanged -> global results -> actual frame OnClick ->
-- SetText("") event -> new list. This previously selected item index zero.
local searchBox
for _, frame in ipairs(created) do
  if frame.kind == "EditBox" and frame.scripts.OnTextChanged then
    searchBox = frame
    break
  end
end
assert(searchBox, "Search EditBox must be wired")
ns.ui.selectCategory("zones")
searchBox:SetText("night")
assert(ns.ui.query == "night")
local searchRow
for _, frame in ipairs(created) do
  if frame.item and frame.item.id == 13 and frame.item.atlasCategory == "fish"
      and frame.scripts.OnClick then searchRow = frame end
end
assert(searchRow, "Global search result must be a clickable row")
searchRow.scripts.OnClick(searchRow, "LeftButton")
assert(ns.ui.category == "fish" and ns.ui.selected().id == 13,
  "Search click must land on selected fish, not Darkclaw Lobster index zero")
assert(ns.ui.query == "" and searchBox:GetText() == "",
  "Programmatic search clear must be handled atomically")
searchBox:SetText("pole")
local poleRow
for _, frame in ipairs(created) do
  if frame.item and frame.item.id == 6256
      and frame.item.atlasCategory == "gear"
      and frame.scripts.OnClick then poleRow = frame end
end
assert(poleRow, "Gear search hit should be clickable")
poleRow.scripts.OnClick(poleRow, "LeftButton")
assert(ns.ui.category == "gear" and ns.ui.selected().id == 6256,
  "Search click must preserve gear result missing from destination listing")
assert(ns.ui.selected().name == "Fishing Pole")
ns.ui.refresh(false)
assert(ns.ui.selected().id == 6256,
  "Refresh must not replace a pinned search result with category index zero")
WorldMapFrame = element()
WorldMapFrame:Hide()
WorldMapFrame.SetMapID = function(self, id) self.mapID = id end
WorldMapFrame.GetMapID = function(self) return self.mapID end
assert(ns.ui.openWorldMap(nil), "World Map must open with no mapped item zone")
assert(ns.ui.openWorldMap(1413), "World Map should open with a selected map")
assert(WorldMapFrame.mapID == 1413)
local properSetMapID = WorldMapFrame.SetMapID
WorldMapFrame.SetMapID = function(self) self.mapID = 999 end
assert(not ns.ui.openWorldMap(1413),
  "A visible World Map on the wrong zone must not count as success")
WorldMapFrame.SetMapID = function() error("Cannot select map") end
assert(not ns.ui.openWorldMap(1413),
  "A World Map SetMapID exception must not count as selection success")
WorldMapFrame.SetMapID = properSetMapID
assert(ns.ui.selectCategory("items", nil, "Items") == nil)
assert(ns.ui.category == "items" and ns.ui.topPage == "Items")
assert(ns.ui.refresh(true) == nil)
assert(ns.ui.toggle())
print("FrameXML explorer mock smoke test passed")
