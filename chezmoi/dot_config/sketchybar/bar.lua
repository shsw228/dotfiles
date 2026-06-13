local sbar = require("sketchybar")
local colors = require("colors")

sbar.bar({
  height    = 32,
  color     = colors.bar.bg,
  border_color = colors.bar.border,
  border_width = 0,
  -- バー自体を画面端から浮かせて独立感を出す
  margin    = 12,   -- 左右の余白
  y_offset  = 6,    -- 上端からの距離
  corner_radius = 10,
  -- notch display (MacBook) では position=center アイテムを notch を挟んで左右に分割する
  notch_width = 200,
  padding_left  = 8,
  padding_right = 8,
  topmost   = "window",
  sticky    = true,
  shadow    = false,
  display   = "all",
})
