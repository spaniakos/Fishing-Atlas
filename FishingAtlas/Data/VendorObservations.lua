-- SPDX-License-Identifier: GPL-3.0-or-later
-- Capture only merchant inventory actually seen in the current Forever client.
local _, ns = ...
ns.vendors = {}
local V = ns.vendors
local MAX_VENDORS, MAX_ITEMS = 2000, 250

function V.npcId(guid)
  if type(guid) ~= "string" then return nil end
  -- Example: Creature-0-0-0-0-12345-0000000000. Never guess a missing NPC ID.
  return tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
end

function V.capture(guid, links, when)
  local npcId = V.npcId(guid)
  if not npcId then return false, "Merchant NPC ID unavailable" end
  if type(links) ~= "table" then return false, "Missing merchant items" end
  if not ns.storage.db then return false, "Storage unavailable" end
  local db = ns.storage.db
  if type(db.vendorObservations) ~= "table" then db.vendorObservations = {} end
  local vendors = db.vendorObservations
  local current = vendors[npcId]
  local found, seen = {}, {}
  for _, link in ipairs(links) do
    local itemId = type(link) == "string" and tonumber(link:match("|Hitem:(%d+)")) or nil
    if itemId and itemId > 0 and not seen[itemId] and #found < MAX_ITEMS then
      seen[itemId] = true
      found[#found + 1] = itemId
    end
  end
  if #found == 0 then return false, "No identified item links" end
  if not current then
    local total = 0
    for _ in pairs(vendors) do total = total + 1 end
    if total >= MAX_VENDORS then return false, "Vendor storage is full" end
    current = {npcId = npcId, items = {}, sightings = 0, source = "client_merchant", build = "1.60.1.70888"}
    vendors[npcId] = current
  end
  table.sort(found)
  current.items = found
  current.lastSeen = tonumber(when) or 0
  current.sightings = current.sightings + 1
  return true, npcId
end

function V.scan()
  if type(UnitGUID) ~= "function" or type(GetMerchantNumItems) ~= "function"
      or type(GetMerchantItemLink) ~= "function" then return end
  local guid = UnitGUID("npc")
  if not V.npcId(guid) then return end
  local count = GetMerchantNumItems()
  if type(count) ~= "number" or count < 1 then return end
  local links = {}
  for i = 1, math.min(count, MAX_ITEMS) do
    local link = GetMerchantItemLink(i)
    if link then links[#links + 1] = link end
  end
  local now = type(time) == "function" and time() or 0
  V.capture(guid, links, now)
end

function V.start()
  if type(CreateFrame) ~= "function" or V.frame then return end
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("MERCHANT_SHOW")
  frame:SetScript("OnEvent", function() V.scan() end)
  V.frame = frame
end
