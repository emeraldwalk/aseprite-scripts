-- Generate a normal map layer from a grayscale height map layer.
-- Uses Sobel operator to compute surface gradients, then converts to an RGB normal map.
-- Output convention: OpenGL (R=right, G=up, B=towards viewer).
-- Transparent pixels in the source remain transparent in the output.
--
-- To use: select the heightmap layer, run this script.

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

-- Show a dialog to let the user tune the strength (Z scale)
local dlg = Dialog("Normal Map from Height Map")
dlg:slider{
  id = "strength",
  label = "Strength (Z scale)",
  min = 1,
  max = 20,
  value = 4
}
dlg:button{ id = "ok", text = "Generate" }
dlg:button{ id = "cancel", text = "Cancel" }
dlg:show()

if not dlg.data.ok then return end

local strength = dlg.data.strength

local srcImg = cel.image
local celPos = cel.position
local w = srcImg.width
local h = srcImg.height

-- Extract the luminance (red channel of grayscale) and alpha for each pixel.
-- We treat the grayscale value as height (0..255).
local heightGrid = {}
local alphaGrid  = {}

for y = 0, h - 1 do
  heightGrid[y] = {}
  alphaGrid[y]  = {}
  for x = 0, w - 1 do
    local px = srcImg:getPixel(x, y)
    alphaGrid[y][x]  = app.pixelColor.rgbaA(px)
    -- Use red channel as the height value (works for both RGB and grayscale images)
    if alphaGrid[y][x] > 0 then
      heightGrid[y][x] = app.pixelColor.rgbaR(px)
    else
      heightGrid[y][x] = 0
    end
  end
end

-- Sample height with edge clamping
local function sampleH(x, y)
  x = math.max(0, math.min(w - 1, x))
  y = math.max(0, math.min(h - 1, y))
  return heightGrid[y][x]
end

-- Sobel operator to compute gradient (dX, dY) at each pixel.
-- Kernel:
--   dX: [-1 0 +1]   dY: [-1 -2 -1]
--       [-2 0 +2]       [ 0  0  0]
--       [-1 0 +1]       [+1 +2 +1]

local nmImg = Image(w, h, ColorMode.RGB)

for y = 0, h - 1 do
  for x = 0, w - 1 do
    if alphaGrid[y][x] > 0 then
      -- Sobel dX (left-to-right gradient)
      local dX = (
        -1 * sampleH(x-1, y-1) + 1 * sampleH(x+1, y-1) +
        -2 * sampleH(x-1, y  ) + 2 * sampleH(x+1, y  ) +
        -1 * sampleH(x-1, y+1) + 1 * sampleH(x+1, y+1)
      ) / 8.0

      -- Sobel dY (top-to-bottom gradient; negate for OpenGL Y-up convention)
      local dY = -(
        -1 * sampleH(x-1, y-1) - 2 * sampleH(x, y-1) - 1 * sampleH(x+1, y-1) +
         1 * sampleH(x-1, y+1) + 2 * sampleH(x, y+1) + 1 * sampleH(x+1, y+1)
      ) / 8.0

      -- Z component is the user-controlled strength (higher = flatter/less effect)
      local dZ = 255.0 / strength

      -- Normalize to unit vector
      local len = math.sqrt(dX * dX + dY * dY + dZ * dZ)
      if len == 0 then len = 1 end
      local nx = dX / len
      local ny = dY / len
      local nz = dZ / len

      -- Map from [-1, 1] to [0, 255]
      local r = math.floor((nx * 0.5 + 0.5) * 255 + 0.5)
      local g = math.floor((ny * 0.5 + 0.5) * 255 + 0.5)
      local b = math.floor((nz * 0.5 + 0.5) * 255 + 0.5)

      r = math.max(0, math.min(255, r))
      g = math.max(0, math.min(255, g))
      b = math.max(0, math.min(255, b))

      nmImg:drawPixel(x, y, app.pixelColor.rgba(r, g, b, 255))
    else
      nmImg:drawPixel(x, y, app.pixelColor.rgba(0, 0, 0, 0))
    end
  end
end

-- Create the normal map layer above the source layer
app.transaction(function()
  local nmLayer = spr:newLayer()
  nmLayer.name = srcLayer.name .. " normalmap"
  nmLayer.stackIndex = srcLayer.stackIndex + 1
  spr:newCel(nmLayer, frame.frameNumber, nmImg, celPos)
end)

app.refresh()
