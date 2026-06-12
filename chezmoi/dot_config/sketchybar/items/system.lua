local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

-- CPU 使用率と物理メモリ使用率をひとつのアイテムにまとめて表示。
-- top と memory_pressure は呼び出しコスト低め (top -n 0 で即返り)
local system = sbar.add("item", "system", {
  position = "right",
  icon = {
    string = icons.system.cpu,
    color  = colors.blue,
    padding_left  = 8,
    padding_right = 2,
  },
  label = {
    color = colors.white,
    padding_right = 8,
    width = 130,
    align = "right",
  },
  update_freq = 5,
})

local function color_for(pct)
  if pct >= 90 then return colors.red
  elseif pct >= 70 then return colors.yellow
  else return colors.white
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
      -- icon は CPU、label に memory アイコンを埋め込んで両方識別可能に
      system:set({
        icon  = { color = color_for(cpu) },
        label = {
          string = string.format("%d%%  %s %d%%", cpu, icons.system.mem, mem),
        },
      })
    end
  )
end

system:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
