local sbar = require("sketchybar")
local colors = require("colors")

sbar.bar({
  height    = 32,
  color     = colors.bar.bg,
  border_color = colors.bar.border,
  border_width = 0,
  margin    = 0,
  y_offset  = 0,
  padding_left  = 6,
  padding_right = 6,
  topmost   = "window",
  sticky    = true,
  shadow    = false,
  display   = "all",
})
