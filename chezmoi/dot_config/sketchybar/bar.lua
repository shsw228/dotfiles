local sbar = require("sketchybar")
local colors = require("colors")

sbar.bar({
  height    = 32,
  color     = colors.bar.bg,
  border_color = colors.bar.border,
  border_width = 0,
  -- y_offset で画面上端からのオフセット。notch handling は notch_width 側で制御。
  margin    = 12,
  y_offset  = 8,
  corner_radius = 10,
  -- notch display (MacBook): notch_width 分を中央から避けて items を左右に振る
  notch_width = 220,
  -- margin で画面端〜バー間 = 12px に揃える。bar.padding は加算されるので 0 にして
  -- yashiki outer-gap(12) と視覚的に一致させる。
  padding_left  = 0,
  padding_right = 0,
  topmost   = "window",
  sticky    = true,
  shadow    = false,
  display   = "all",
})
