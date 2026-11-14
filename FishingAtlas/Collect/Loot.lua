-- SPDX-License-Identifier: GPL-3.0-or-later
-- Fishing loot journal. Some Forever clients do not reliably identify loot
-- using IsFishingLoot or emit LOOT_SLOT_CLEARED for every auto-looted item.
-- Record only CONFIRMED acquisitions, never just items visible in a window.
local _, ns = ...
ns.loot = {}
local L = ns.loot
local slots, pending = {}, {}
local fishing, openedAt, lastFishingCast = false, nil, nil
local WINDOW_SECONDS, CAST_SECONDS = 5, 40
local stats = {opened = 0, fishingWindows = 0, castEvents = 0,
  cleared = 0, chatConfirmed = 0, recorded = 0, ignored = 0}

local function clock()
  if type(GetTime) == "function" then return GetTime() end
  if type(time) == "function" then return time() end
  return 0
end

local function recent(when, seconds)
  local now = clock()
  return when ~= nil and now >= when and now - when <= seconds
end

local function itemID(link)
  if type(link) ~= "string" then return nil end
  return tonumber(link:match("|Hitem:(%d+)"))
    or tonumber(link:match("item:(%d+)"))
end

local function changed()
  if ns.ui and ns.ui.refresh then ns.ui.refresh(false) end
end

local function record(entry, method)
  if not entry or entry.recorded then return end
  local result = ns.journal.record(entry.id, entry.name, entry.quantity,
    "fishing_loot")
  if not result then return end
  entry.recorded = true
  stats.recorded = stats.recorded + 1
  if method == "cleared" then stats.cleared = stats.cleared + 1
  else stats.chatConfirmed = stats.chatConfirmed + 1 end
  changed()
end

function L.noteCast(...)
  local args = {...}
  local localized
  if type(GetSpellInfo) == "function" then
    localized = GetSpellInfo(7620)
  elseif type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
    local info = C_Spell.GetSpellInfo(7620)
    localized = info and info.name
  end
  for _, value in ipairs(args) do
    if value == "Fishing" or (type(localized) == "string"
        and value == localized) then
      lastFishingCast = clock()
      stats.castEvents = stats.castEvents + 1
      return true
    end
  end
  return false
end

function L.open()
  slots, pending = {}, {}
  openedAt = clock()
  stats.opened = stats.opened + 1
  local flagged = type(IsFishingLoot) == "function" and IsFishingLoot()
  fishing = flagged == true or recent(lastFishingCast, CAST_SECONDS)
  if not fishing then stats.ignored = stats.ignored + 1; return false end
  stats.fishingWindows = stats.fishingWindows + 1
  if type(GetNumLootItems) ~= "function" or
      type(GetLootSlotInfo) ~= "function" then return false end
  for slot = 1, GetNumLootItems() do
    local _, name, quantity = GetLootSlotInfo(slot)
    local link = type(GetLootSlotLink) == "function" and
      GetLootSlotLink(slot) or nil
    if type(name) ~= "string" and type(link) == "string" then
      name = link:match("%[([^%]]+)%]")
    end
    if type(name) == "string" and name ~= "" and
        type(quantity) == "number" and quantity >= 1 then
      local entry = {id = itemID(link), name = name, quantity = quantity}
      slots[slot] = entry
      pending[#pending + 1] = entry
    end
  end
  return true
end

function L.cleared(slot)
  if not fishing then return end
  local entry = slots[slot]
  slots[slot] = nil
  record(entry, "cleared")
end

-- CHAT_MSG_LOOT is a second confirmation path for auto-loot, which may skip
-- LOOT_SLOT_CLEARED. Match a specific item in the last fishing loot window,
-- and reject party loot messages; do not count a window without confirmation.
function L.chat(message)
  if not recent(openedAt, WINDOW_SECONDS) or
      type(message) ~= "string" or
      not (message:find("^You receive loot") or
        message:find("^You receive item")) then return false end
  local id = itemID(message)
  local name = message:match("%[([^%]]+)%]")
  for _, entry in ipairs(pending) do
    if not entry.recorded and ((id and entry.id == id)
        or (not id and name and entry.name == name)) then
      record(entry, "chat")
      return entry.recorded == true
    end
  end
  return false
end

function L.closed()
  fishing = false
  slots = {}
  -- Keep the matched pending snapshot briefly: the client's final chat
  -- confirmation can arrive AFTER LOOT_CLOSED.
end

function L.debug()
  return string.format("Loot: opened %d, fishing windows %d, casts %d, " ..
    "slot confirmations %d, chat confirmations %d, recorded %d, " ..
    "unidentified windows %d; IsFishingLoot %s",
    stats.opened, stats.fishingWindows, stats.castEvents, stats.cleared,
    stats.chatConfirmed, stats.recorded, stats.ignored,
    type(IsFishingLoot) == "function" and "available" or "missing")
end

function L.start()
  if type(CreateFrame) ~= "function" or L.frame then return end
  local frame = CreateFrame("Frame")
  for _, event in ipairs({"LOOT_OPENED", "LOOT_SLOT_CLEARED",
      "LOOT_CLOSED", "CHAT_MSG_LOOT", "UNIT_SPELLCAST_START",
      "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START"}) do
    -- A missing optional event must not abort addon initialization.
    pcall(frame.RegisterEvent, frame, event)
  end
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "LOOT_OPENED" then L.open()
    elseif event == "LOOT_SLOT_CLEARED" then L.cleared(...)
    elseif event == "LOOT_CLOSED" then L.closed()
    elseif event == "CHAT_MSG_LOOT" then L.chat(...)
    elseif event:find("^UNIT_SPELLCAST") then
      local unit = ...
      if unit == "player" then L.noteCast(select(2, ...)) end
    end
  end)
  L.frame = frame
end
