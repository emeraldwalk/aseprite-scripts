-- Import PNG rows as layers in a new sprite
-- Each row becomes one layer
-- User specifies tile height and tile width
-- Each layer is split into frames based on tile width

local dlg = Dialog("Import Rows as Layers")

dlg:file{
  id="file",
  label="PNG File",
  open=true,
  filetypes={"png"}
}

dlg:number{
  id="tile_h",
  label="Tile Height",
  text="32"
}

dlg:number{
  id="tile_w",
  label="Tile Width",
  text="32"
}

dlg:button{
  id="ok",
  text="Import"
}

dlg:button{
  id="cancel",
  text="Cancel"
}

dlg:show()

local data = dlg.data
if not data.ok or not data.file then
  return
end

local tile_h = tonumber(data.tile_h)
if not tile_h or tile_h <= 0 then
  app.alert("Invalid tile height.")
  return
end

local tile_w = tonumber(data.tile_w)
if not tile_w or tile_w <= 0 then
  app.alert("Invalid tile width.")
  return
end

-- Load source image
local srcSprite = app.open(data.file)
local srcImage = srcSprite.cels[1].image

local width = srcSprite.width
local height = srcSprite.height

local rows = math.floor(height / tile_h)
local frames = math.floor(width / tile_w)

if rows * tile_h ~= height then
  app.alert("Height not divisible by tile height.")
  return
end

if frames * tile_w ~= width then
  app.alert("Width not divisible by tile width.")
  return
end

-- Create new sprite (start with one frame), then add frames explicitly
local newSprite = Sprite(tile_w, tile_h, srcImage.colorMode)
newSprite.filename = "imported_frames.aseprite"

-- Add additional frames if needed (newFrame creates one frame each call)
for i = 2, frames do
  newSprite:newFrame()
end

-- Remove default layer
newSprite:deleteLayer(newSprite.layers[1])

app.transaction(function()
  for r = 0, rows - 1 do
    local layer = newSprite:newLayer()
    layer.name = "Row " .. (r + 1)

    for f = 1, frames do
      local img = Image(tile_w, tile_h, srcImage.colorMode)

      img:drawImage(
        srcImage,
        Point(-(f-1) * tile_w, -r * tile_h)
      )

      newSprite:newCel(layer, f, img)
    end
  end
end)

app.activeSprite = newSprite

app.alert("Imported " .. rows .. " layers with " .. frames .. " frames each!")
