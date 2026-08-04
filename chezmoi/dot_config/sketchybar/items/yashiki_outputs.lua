local settings = require("settings")

-- 起動時に yashiki list-outputs を読んで、ディスプレイを検出。
-- 各 yashiki output_id を sketchybar 側の display index (1=main, 2..=secondary) に
-- マップする。items/yashiki.lua と items/yashiki_indicator.lua が共有する。
local f = io.popen(settings.paths.yashiki .. " list-outputs 2>&1")
local outputs = {}
if f then
  local raw = f:read("*a")
  f:close()

  local main_id
  local others = {}
  for line in raw:gmatch("[^\n]+") do
    local id = line:match("^(%d+):")
    if id then
      if line:find("%(main%)") then
        main_id = id
      else
        table.insert(others, id)
      end
    end
  end

  if main_id then
    table.insert(outputs, { yashiki_id = main_id, sb_display = 1 })
  end
  for _, id in ipairs(others) do
    table.insert(outputs, { yashiki_id = id, sb_display = #outputs + 1 })
  end
end
if #outputs == 0 then
  table.insert(outputs, { yashiki_id = "1", sb_display = 1 })
end

return outputs
