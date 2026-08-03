local sbar = require("sketchybar")
local colors = require("colors")
local styles = require("styles")

-- 時刻表示。中央配置で notch ディスプレイでは notch の右側に出る (date より後で追加)
local clock = sbar.add("item", "clock", {
  position = "center",
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = {
    color = colors.fg,
    padding_left  = 8,
    padding_right = 8,
  },
  blur_radius = styles.pill.blur_radius,
  background = styles.pill.background,
  update_freq = 30,
})

local function refresh()
  clock:set({ label = { string = os.date("%H:%M") } })
end

clock:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
