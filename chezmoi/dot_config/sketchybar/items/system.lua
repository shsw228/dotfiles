local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")
local displays = require("displays")

-- CPU/RAM は MacBook 本体側 (notch ディスプレイ) には出さない方針。
-- 外部モニタが無い場合は表示する。
local target_display = displays.external_indices[1]
if displays.builtin_index and not target_display then
  return  -- Built-in しか無い → 表示しない
end

-- CPU 使用率と物理メモリ使用率をひとつのアイテムにまとめて表示。
-- top と memory_pressure は呼び出しコスト低め (top -n 0 で即返り)
-- icon 領域は使わず、label の中に "cpuアイコン+% memアイコン+%" を全部詰めて
-- アイコン⇔数値の余分なpaddingが入らないようにする
local system = sbar.add("item", "system", {
  position = "right",
  associated_display = target_display,
  -- icon は非表示。padding を 0 にして空のスペースが残らないようにする
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = {
    color = colors.fg,
    padding_left  = 8,
    padding_right = 8,
  },
  update_freq = 5,
})

local function color_for(pct)
  if pct >= 90 then return colors.red
  elseif pct >= 70 then return colors.yellow
  else return colors.fg
  end
end

local function refresh()
  sbar.exec(
    -- CPU 使用率 (user + sys) と memory free% をワンライナーで取得
    "cpu=$(top -l 1 -n 0 -F | awk '/CPU usage/{gsub(\"%\",\"\"); printf \"%d\", $3 + $5}'); "
      .. "mem=$(memory_pressure 2>/dev/null | awk '/System-wide memory free/{gsub(\"%\",\"\"); printf \"%d\", 100 - $5}'); "
      .. "echo \"$cpu|$mem\"",
    function(result)
      local cpu_str, mem_str = (result or ""):match("^(%d+)|(%d+)")
      local cpu = tonumber(cpu_str) or 0
      local mem = tonumber(mem_str) or 0
      local worst = math.max(cpu, mem)
      system:set({
        label = {
          string = string.format("CPU %d%%  RAM %d%%", cpu, mem),
          color = color_for(cpu),
        },
      })
    end
  )
end

system:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
