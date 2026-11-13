-- SPDX-License-Identifier: GPL-3.0-or-later
-- The WoW client cannot safely assume it may launch a system web browser.
-- Present a copyable GitHub URL rather than invent an unsupported external action.
local _, ns = ...
ns.issues = {
  url = "https://github.com/spaniakos/Fishing-Atlas/issues/new/choose"
}
local I = ns.issues
local frame, field

function I.open()
  if type(CreateFrame) ~= "function" or not UIParent then
    if ns.commands and ns.commands.say then ns.commands.say(I.url) end
    return false
  end
  if not frame then
    frame = CreateFrame("Frame", "FishingAtlasIssueLink", UIParent)
    frame:SetSize(560, 140)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\FishingAtlas\\Art\\deepwater-background")
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -18)
    title:SetText("Report a Fishing Atlas issue on GitHub")
    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    hint:SetText("Press Ctrl+C to copy. Open the link in your browser.")
    field = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    field:SetSize(512, 28)
    field:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -80)
    field:SetAutoFocus(false)
    field:SetMaxLetters(200)
    field:SetScript("OnEscapePressed", function() frame:Hide() end)
    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(65, 24)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 10)
    close:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)
    frame:Hide()
  end
  field:SetText(I.url)
  frame:Show()
  field:SetFocus()
  field:HighlightText()
  return true
end
