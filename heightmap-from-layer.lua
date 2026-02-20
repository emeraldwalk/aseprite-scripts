-- Generate a height map layer from the active layer using distance field (pillow emboss)
-- blended with source pixel luminance.
-- Distance field: interior = white (high), edge = black (low).
-- Luminance: bright source pixels = high, dark source pixels = low.
-- The blend ratio is user-controlled. Designed for use as input to normal map generation.

local spr = app.activeSprite
if not spr then
  app.alert("No active sprite.")
  return
end

local srcLayer = app.activeLayer
if not srcLayer then
  app.alert("No active layer.")
  return
end

if srcLayer.isGroup then
  app.alert("Please select a regular image layer, not a group.")
  return
end

local frame = app.activeFrame
if not frame then
  app.alert("No active frame.")
  return
end

local cel = srcLayer:cel(frame.frameNumber)
if not cel then
  app.alert("No cel on the active layer/frame.")
  return
end

-- Show dialog for blend control
local dlg = Dialog("Height Map from Layer")
dlg:slider{
  id = "luminance_blend",
  label = "Luminance blend %",
  min = 0,
  max = 100,
  value = 30
}
dlg:button{ id = "ok", text = "Generate" }
dlg:button{ id = "cancel", text = "Cancel" }
dlg:show()

if not dlg.data.ok then return end

local luminanceBlend = dlg.data.luminance_blend / 100.0
local distBlend = 1.0 - luminanceBlend

local srcImg = cel.image
local celPos = cel.position
local w = srcImg.width
local h = srcImg.height

-- Build an opacity grid: true = opaque (alpha > 0), false = transparent
local opaque = {}
for y = 0, h - 1 do
  opaque[y] = {}
  for x = 0, w - 1 do
    local px = srcImg:getPixel(x, y)
    -- app.pixelColor.rgbaA returns the alpha component
    opaque[y][x] = (app.pixelColor.rgbaA(px) > 0)
  end
end

-- BFS distance transform: distance from each opaque pixel to the nearest non-opaque boundary.
-- Seed = opaque pixels that are adjacent to a transparent pixel (or cel border).
-- Uses Chebyshev distance (8-connectivity) for a natural pixel-art look.

local dist = {}
for y = 0, h - 1 do
  dist[y] = {}
  for x = 0, w - 1 do
    dist[y][x] = -1  -- unvisited
  end
end

local queue = {}
local qHead = 1

local function enqueue(x, y, d)
  queue[#queue + 1] = {x, y, d}
end

-- Seed: opaque pixels on the edge of the opaque region
local dirs = {
  {-1, 0}, {1, 0}, {0, -1}, {0, 1},
  {-1, -1}, {-1, 1}, {1, -1}, {1, 1}
}

for y = 0, h - 1 do
  for x = 0, w - 1 do
    if opaque[y][x] then
      local isEdge = false
      -- Check if any neighbor is transparent or outside the cel bounds
      for _, d in ipairs(dirs) do
        local nx, ny = x + d[1], y + d[2]
        if nx < 0 or ny < 0 or nx >= w or ny >= h then
          isEdge = true
          break
        elseif not opaque[ny][nx] then
          isEdge = true
          break
        end
      end
      if isEdge then
        dist[y][x] = 0
        enqueue(x, y, 0)
      end
    else
      -- Transparent pixels get distance 0 as well (won't be drawn)
      dist[y][x] = 0
    end
  end
end

-- BFS flood fill inward
while qHead <= #queue do
  local entry = queue[qHead]
  qHead = qHead + 1
  local cx, cy, cd = entry[1], entry[2], entry[3]

  for _, d in ipairs(dirs) do
    local nx, ny = cx + d[1], cy + d[2]
    if nx >= 0 and ny >= 0 and nx < w and ny < h then
      if opaque[ny][nx] and dist[ny][nx] == -1 then
        dist[ny][nx] = cd + 1
        enqueue(nx, ny, cd + 1)
      end
    end
  end
end

-- Find max distance for normalization
local maxDist = 0
for y = 0, h - 1 do
  for x = 0, w - 1 do
    if dist[y][x] > maxDist then
      maxDist = dist[y][x]
    end
  end
end

-- Build the height map image (RGBA so we can preserve transparency)
local hmImg = Image(w, h, ColorMode.RGB)

for y = 0, h - 1 do
  for x = 0, w - 1 do
    if opaque[y][x] then
      -- Distance field component (0..255)
      local d = dist[y][x]
      local distVal
      if maxDist == 0 then
        distVal = 255
      else
        distVal = (d / maxDist) * 255
      end

      -- Luminance component: perceived brightness of the source pixel
      -- Uses standard Rec. 709 coefficients
      local px = srcImg:getPixel(x, y)
      local r = app.pixelColor.rgbaR(px)
      local g = app.pixelColor.rgbaG(px)
      local b = app.pixelColor.rgbaB(px)
      local lumVal = 0.2126 * r + 0.7152 * g + 0.0722 * b

      -- Blend: distBlend * distanceField + luminanceBlend * luminance
      local v = math.floor(distBlend * distVal + luminanceBlend * lumVal + 0.5)
      v = math.max(0, math.min(255, v))

      hmImg:drawPixel(x, y, app.pixelColor.rgba(v, v, v, 255))
    else
      hmImg:drawPixel(x, y, app.pixelColor.rgba(0, 0, 0, 0))
    end
  end
end

-- Create the new layer above the source layer and add the cel
app.transaction(function()
  local hmLayer = spr:newLayer()
  hmLayer.name = srcLayer.name .. " heightmap"

  -- Move the new layer just above the source layer
  local targetStackIndex = srcLayer.stackIndex + 1
  hmLayer.stackIndex = targetStackIndex

  spr:newCel(hmLayer, frame.frameNumber, hmImg, celPos)
end)

app.refresh()
