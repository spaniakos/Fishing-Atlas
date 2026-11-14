-- SPDX-License-Identifier: GPL-3.0-or-later
local ns = {}
assert(loadfile("FishingAtlas/UI/ZoneMap.lua"))("FishingAtlas", ns)
local layout = ns.zoneMap.layout({layerWidth = 512, layerHeight = 256,
  tileWidth = 256, tileHeight = 256}, {101, 102}, 256, 128)
assert(#layout == 2)
assert(layout[1].texture == 101 and layout[2].texture == 102)
assert(layout[1].x == 0 and layout[2].x == 128)
assert(layout[1].w == 128 and layout[1].h == 128)
assert(#ns.zoneMap.layout({}, {}, 100, 100) == 0)
assert(#ns.zoneMap.layout({layerWidth=256,layerHeight=256,
  tileWidth=128,tileHeight=128}, {1,2,3,4}, 256, 256) == 4)
C_Map = {
  GetMapArtLayers = function()
    return {{layerWidth = 512, layerHeight = 512,
      tileWidth = 256, tileHeight = 256}}
  end,
  GetMapArtLayerTextures = function()
    return {101, 0, 103} -- 2 of 4 tiles in a partially installed client map
  end,
}
local tiles, _, _, _, _, meta = ns.zoneMap.artForMap(1439, 256, 256)
assert(#tiles == 2 and meta.tiles == 2 and meta.expected == 4)
assert(meta.coverage == 0.5, "Partial tiles must not be advertised as a full map")
assert(ns.zoneMap.describe(1439):find("2/4", 1, true))
-- The client reports all base files, but the visible map also requires
-- exploration overlays. Test the actual map-art composition primitives.
C_Map.GetMapArtLayerTextures = function()
  return {101, 102, 103, 104}
end
C_MapExplorationInfo = {
  GetExploredMapTextures = function()
    return {
      {textureWidth = 512, textureHeight = 256, offsetX = 0,
        offsetY = 256, fileDataIDs = {201, 202}},
      {textureWidth = 256, textureHeight = 256, offsetX = 256,
        offsetY = 0, isShownByMouseOver = true, fileDataIDs = {203}}
    }
  end
}
local base, ox, oy, w, h, m = ns.zoneMap.artForMap(1439, 256, 256)
assert(#base == 4 and m.tiles == 4 and m.expected == 4)
local overlay = ns.zoneMap.exploredForMap(1439, m, ox, oy, w, h)
assert(#overlay == 2, "Explored terrain must overlay complete base map tiles")
assert(overlay[1].texture == 201 and overlay[2].texture == 202)
assert(overlay[1].y == 128 and overlay[2].x == 128)
assert(ns.zoneMap.describe(1439):find("2 overlay tiles", 1, true))
local clipped = ns.zoneMap.explorationLayout({
  {textureWidth = 256, textureHeight = 256,
    offsetX = -64, offsetY = -64, fileDataIDs = {201}}
}, 512, 512, 0, 0, 256, 256)
assert(#clipped == 1 and clipped[1].x == 0 and clipped[1].y == 0)
assert(clipped[1].u0 == 0.25 and clipped[1].v0 == 0.25,
  "Clipped overlays must not spill into adjacent UI panels")
-- Integration: ensure actual preview render creates base textures and puts
-- exploration art ABOVE them (layout-only checks miss this wiring).
local textures = {}
local function sprite(layer)
  local t = {layer = layer}
  local methods = {"Hide", "Show", "SetAllPoints", "SetVertexColor",
    "SetPoint", "SetSize", "SetTexCoord", "ClearAllPoints", "SetWidth",
    "SetJustifyH", "SetText"}
  for _, name in ipairs(methods) do t[name] = function() end end
  t.SetTexture = function(self, value) self.texture = value end
  t.IsObjectLoaded = function(self) return self.texture ~= 102 end
  return t
end
local fake = {
  GetWidth = function() return 256 end,
  GetHeight = function() return 256 end,
  IsShown = function() return true end,
  CreateTexture = function(_, _, layer)
    local t = sprite(layer)
    textures[#textures + 1] = t
    return t
  end,
  CreateFontString = function() return sprite("OVERLAY") end
}
CreateFrame = function() return sprite("FRAME") end
local scheduled = {}
C_Timer = {After = function(_, callback)
  scheduled[#scheduled + 1] = callback
end}
assert(ns.zoneMap.render(fake, 1439, {}))
assert(#scheduled == 1,
  "Even a complete 12/12 tile-ID map needs bounded async rendering retries")
scheduled[1]()
assert(#scheduled == 2, "A complete-ID art map gets two streaming retries")
scheduled[2]()
assert(#scheduled == 2, "Streaming retries must stop and never loop forever")
local baseCount, explorationCount = 0, 0
for _, t in ipairs(textures) do
  if t.layer == "BACKGROUND" and type(t.texture) == "number" then
    baseCount = baseCount + 1
  elseif t.layer == "ARTWORK" and type(t.texture) == "number" then
    explorationCount = explorationCount + 1
  end
end
assert(baseCount == 4 and explorationCount == 2,
  "Preview must render both complete base layer AND two exploration textures")
local loadReport = ns.zoneMap.describe(1439)
assert(loadReport:find("3/4 loaded", 1, true),
  "The preview must distinguish rendered textures from C_Map file references")
assert(loadReport:find("2:102", 1, true),
  "The preview must report an unloaded tile slot and its FileDataID")
-- Real prebuilt Forever art references: the character may report ZERO
-- explored overlays even when historical full-zone overlays exist in DB2.
-- Only use these references if art ID + tile size match the running client.
assert(loadfile("FishingAtlas/Data/ClassicMapOverlays.lua"))("FishingAtlas", ns)
assert(ns.data.classicMapOverlaysBuild == "1.60.1.70338")
assert(ns.data.classicMapOverlays[2150],
  "Deadwind Pass art 2150 needs offline unfogged overlay references")
local actualMapArt = 2150
C_Map.GetMapArtID = function() return actualMapArt end
local baseTiles, offX, offY, viewW, viewH, referenceMeta =
  ns.zoneMap.artForMap(1430, 256, 256)
assert(#baseTiles == 4)
local full, source, id = ns.zoneMap.fullOverlayRecords(1430, referenceMeta)
assert(source == "historical_full_reference" and id == 2150)
assert(#full == 3, "Known Deadwind full map has 3 overlay groups")
local fullArt, mode = ns.zoneMap.exploredForMap(1430, referenceMeta,
  offX, offY, viewW, viewH)
assert(#fullArt > 0 and mode == "historical_full_reference",
  "Unexplored player maps should use validated full-reference overlays")
actualMapArt = 998877
local missing, why = ns.zoneMap.fullOverlayRecords(1430, referenceMeta)
assert(missing == nil and why:find("no indexed overlays", 1, true),
  "Never apply an old overlay to a changed client art ID")
local fall, fallbackSource = ns.zoneMap.exploredForMap(1430,
  referenceMeta, offX, offY, viewW, viewH)
assert(#fall == 2 and fallbackSource == "character_exploration",
  "On mismatch, fall back to character's own explored overlays")
actualMapArt = 2150
referenceMeta.tileWidth = 128
assert(not ns.zoneMap.fullOverlayRecords(1430, referenceMeta),
  "Do not use overlays when the client changed map tile dimensions")
print("WoW map art tests: drawn base, exploration, full-reference and compatibility gate passed")
