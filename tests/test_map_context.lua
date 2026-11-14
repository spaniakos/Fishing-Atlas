-- SPDX-License-Identifier: GPL-3.0-or-later
-- Parent-map context uses the actual client rectangle with safe clipping.
local ns = {storage = {db = {settings = {mapContext = true}}}}
assert(loadfile("FishingAtlas/UI/ZoneMap.lua"))("FishingAtlas", ns)
assert(loadfile("FishingAtlas/Atlas/MapContext.lua"))("FishingAtlas", ns)
local mapInfo = {parentMapID = 12}
C_Map = {
  IsCityMap = function() return false end,
  GetMapInfo = function(id) return id == 99 and mapInfo or nil end,
  GetMapRectOnMap = function() return 0.25, 0.75, 0.25, 0.75 end,
  GetMapArtLayers = function()
    return {{layerWidth = 512, layerHeight = 512, tileWidth = 256, tileHeight = 256}}
  end,
  GetMapArtLayerTextures = function() return {101, 102, 103, 104} end
}
local geometry = ns.mapContext.geometry(99)
assert(geometry and geometry.parentID == 12 and geometry.spanX == 0.5)
local tiles, status = ns.mapContext.tiles(99, 0, 0, 256, 256)
assert(#tiles == 4 and status:find("parent 12", 1, true))
assert(tiles[1].x == 0 and tiles[1].y == 0)
assert(tiles[1].w == 128 and tiles[1].h == 128)
assert(tiles[1].u0 == 0.5 and tiles[1].u1 == 1,
  "Clipped parent texture must use the correct portion of its FileDataID")
for _, tile in ipairs(tiles) do
  assert(tile.x >= 0 and tile.y >= 0 and tile.x + tile.w <= 256.00001
    and tile.y + tile.h <= 256.00001,
    "Parent geography may never spill outside the target map")
end
C_Map.IsCityMap = function() return true end
assert(ns.mapContext.geometry(99) == nil, "City art must not inherit parent terrain")
C_Map.IsCityMap = function() return false end
-- When world-coordinate conversions are available, cross-check transforms.
C_Map.GetWorldPosFromMapPos = function() return 1, {x = 1000, y = 2000} end
C_Map.GetMapWorldSize = function() return 1000, 1000 end
assert(ns.mapContext.geometry(99), "Aligned world coordinates permit context")
C_Map.GetWorldPosFromMapPos = function(id)
  return id == 99 and 1 or 2, {x = 1000, y = 2000}
end
assert(not ns.mapContext.geometry(99), "Different map instances must be rejected")
C_Map.GetWorldPosFromMapPos = function(id)
  return 1, id == 99 and {x = 1000, y = 2000} or {x = 3000, y = 4000}
end
assert(not ns.mapContext.geometry(99), "Misaligned world projections must be rejected")
C_Map.GetWorldPosFromMapPos = nil
ns.storage.db.settings.mapContext = false
assert(#ns.mapContext.tiles(99, 0, 0, 256, 256) == 0)
ns.storage.db.settings.mapContext = true
C_Map.GetMapRectOnMap = function() return 0.7, 0.1, 0, 1 end
assert(ns.mapContext.geometry(99) == nil, "Inverted parent bounds must be rejected")
C_Map.GetMapRectOnMap = function() error("API not supported by this build") end
assert(ns.mapContext.geometry(99) == nil, "Unsupported client must use safe fallback")
C_Map.GetMapRectOnMap = nil
assert(ns.mapContext.geometry(99) == nil)
print("parent-art geographic transform, clipping, city guards and fallback passed")
