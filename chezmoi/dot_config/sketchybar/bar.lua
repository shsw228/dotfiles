local sbar = require("sketchybar")
local colors = require("colors")

sbar.bar({
  height    = 32,
  color     = colors.bar.bg,
  border_color = colors.bar.border,
  border_width = 0,
  -- y_offset で画面上端からのオフセット。notch handling は notch_width 側で制御。
  margin    = 12,
  y_offset  = 4,
  corner_radius = 10,
  -- notch display (MacBook): notch_width 分を中央から避けて items を左右に振る
  notch_width = 220,
  padding_left  = 8,
  padding_right = 8,
  topmost   = "window",
  sticky    = true,
  shadow    = false,
  display   = "all",
})
