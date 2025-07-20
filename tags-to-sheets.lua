-- Export each tag into a different sprite sheet
-- Tweaked version of: https://github.com/adamyounis/Aseprite-Tools/blob/main/Tags-To-Sheets/Tags-To-Sheets.lua

local spr = app.activeSprite
if not spr then return print('No active sprite') end

local columns = nil
local dlg = Dialog{ title = "Export Sprite Sheets" }
dlg:number{ id="columns", label="Columns per Sheet (0 = auto)", text="0", decimals=0 }
dlg:button{ id="ok", text="OK" }
dlg:button{ id="cancel", text="Cancel" }
dlg:show()
local data = dlg.data
if not data or not data.columns then return end
columns = tonumber(data.columns) or 0

local path,title = spr.filename:match("^(.+[/\\])(.-).([^.]*)$")

local function make_filepath(path, title, tagname)
  return string.lower(path .. title .. '/' .. title .. '_' .. tagname .. '.png')
end

local msg = { "Do you want to export/overwrite the following files?" }
for i,tag in ipairs(spr.tags) do
  local filepath = make_filepath(path, title, tag.name)
  table.insert(msg, '-' .. filepath)
end

if app.alert{ title="Export Sprite Sheets", text=msg,
              buttons={ "&Yes", "&No" } } ~= 1 then
  return
end

for i,tag in ipairs(spr.tags) do
  local filepath = make_filepath(path, title, tag.name)
  local exportArgs = {
    ui=false,
    mergeDuplicates=true,
    type=SpriteSheetType.ROWS,
    textureFilename=filepath,
    -- dataFilename=filepath:gsub('%.png$', '.json'),
    dataFormat=SpriteSheetDataFormat.JSON_ARRAY,
    tag=tag.name,
    listLayers=false,
    listTags=false,
    listSlices=false,
  }
  if columns and columns > 0 then
    exportArgs.columns = columns
  end
  app.command.ExportSpriteSheet(exportArgs)
end