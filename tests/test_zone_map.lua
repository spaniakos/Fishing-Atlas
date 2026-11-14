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
  t.SetDrawLayer = function(self, drawLayer, sublevel)
    self.drawLayer, self.sublevel = drawLayer, sublevel
  end
  t.IsObjectLoaded = function(self) return self.texture ~= 102 end
  return t
end
local fake = {
  visible = true,
  IsVisible = function(self) return self.visible end,
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
fake.visible = false
assert(ns.zoneMap.describe(1439):find("no matching visible preview", 1, true),
  "Hidden previews must never be diagnosed as visible")
fake.visible = true
assert(ns.zoneMap.describe(1439):find("3/4 loaded", 1, true),
  "Visible preview must remain eligible after being shown again")
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
-- Power-of-two backing for small and partial WorldMapOverlayTile textures.
local small = ns.zoneMap.explorationLayout({
  {textureWidth = 128, textureHeight = 128, offsetX = 0, offsetY = 0,
    fileDataIDs = {555}}
}, 512, 512, 0, 0, 256, 256)
assert(#small == 1 and small[1].u1 == 1 and small[1].v1 == 1,
  "A 128x128 texture must be sampled fully, not as a quarter of 256x256")
local narrow = ns.zoneMap.explorationLayout({
  {textureWidth = 256, textureHeight = 115, offsetX = 0, offsetY = 0,
    fileDataIDs = {556}}
}, 512, 512, 0, 0, 256, 256)
assert(#narrow == 1 and narrow[1].u1 == 1
    and math.abs(narrow[1].v1 - 115 / 128) < 0.00001,
  "A 256x115 overlay must use 256x128 backing coordinates")
local large = ns.zoneMap.explorationLayout({
  {textureWidth = 384, textureHeight = 384, offsetX = 0, offsetY = 0,
    fileDataIDs = {557, 558, 559, 560}, isDrawOnTopLayer = true}
}, 512, 512, 0, 0, 256, 256)
assert(#large == 4 and large[4].u1 == 1 and large[4].v1 == 1,
  "384x384 overlays must use all four row-major textures")
assert(large[1].topLayer, "Overlays with isDrawOnTopLayer must retain stacking")
local origLayers, origTextures = C_Map.GetMapArtLayers, C_Map.GetMapArtLayerTextures
C_Map.GetMapArtLayers = function()
  return {
    {layerWidth = 512, layerHeight = 512, tileWidth = 256, tileHeight = 256},
    {layerWidth = 1024, layerHeight = 1024, tileWidth = 256, tileHeight = 256}
  }
end
C_Map.GetMapArtLayerTextures = function(_, index)
  if index == 1 then return {1, 2, 3, 4} end
  return {11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26}
end
local _, _, _, _, _, chosenMeta = ns.zoneMap.artForMap(1439, 256, 256)
assert(chosenMeta.layer == 1,
  "Equal-coverage alternate art layers must not displace the base overlay layer")
C_Map.GetMapArtLayers, C_Map.GetMapArtLayerTextures = origLayers, origTextures
-- Missing historical file IDs must not shift every subsequent grid position.
ns.data.classicMapOverlays[999991] = {256, 256, {512, 256, 0, 0, 0, 9002}}
actualMapArt = 999991
referenceMeta.tileWidth = 256
local kept = ns.zoneMap.fullOverlayRecords(1430, referenceMeta)
assert(#kept == 1 and kept[1].fileDataIDs[1] == 0
    and kept[1].fileDataIDs[2] == 9002,
  "A missing historical texture must retain its zero slot")
local keptParts = ns.zoneMap.explorationLayout(kept, 512, 512, 0, 0, 256, 256)
assert(#keptParts == 1 and keptParts[1].x == 128,
  "The second overlay tile must remain in the second grid column")
-- Clearing a preview must erase previous load diagnostics.
assert(ns.zoneMap.render(fake, nil, {}) == false)
assert(ns.zoneMap.describe(1439):find("no matching visible preview", 1, true),
  "Clearing the selected map must invalidate the old texture report")
print("WoW map art tests: overlay backing, stacking, visibility, slots and layer preference passed")
