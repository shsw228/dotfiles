local settings = require("settings")

-- 起動時に aerospace list-monitors を読んでディスプレイを検出する。
-- 各 monitor-id を sketchybar 側の display index (1=main, 2..=secondary) に
-- マップする。items/aerospace.lua と items/aerospace_indicator.lua が共有する。
--
-- AeroSpace の monitor-id は左から右への 1 始まりで、sketchybar の display index
-- とは順序が一致しない。main がどれかは --focused ではなく list-monitors の
-- mouse/main 判定に頼れないので、main を先頭に寄せてから残りを並べる。
local AEROSPACE = settings.paths.aerospace

local function query(args)
  local f = io.popen(AEROSPACE .. " " .. args .. " 2>/dev/null")
  if not f then return "" end
  local raw = f:read("*a") or ""
  f:close()
  return raw
end

local outputs = {}

local main_id = query("list-monitors --mouse --format '%{monitor-id}'"):match("%d+")
local ids = {}
for id in query("list-monitors --format '%{monitor-id}'"):gmatch("%d+") do
  table.insert(ids, id)
end

-- main を display 1 に固定し、残りを順に 2.. へ。yashiki 時代と同じ並び。
if main_id then
  table.insert(outputs, { aerospace_id = main_id, sb_display = 1 })
end
for _, id in ipairs(ids) do
  if id ~= main_id then
    table.insert(outputs, { aerospace_id = id, sb_display = #outputs + 1 })
  end
end
if #outputs == 0 then
  table.insert(outputs, { aerospace_id = "1", sb_display = 1 })
end

return outputs
