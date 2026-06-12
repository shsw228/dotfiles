local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")

sbar.default({
  updates       = "when_shown",
  icon = {
    font  = {
      family = settings.font.icons,
      style  = "Bold",
      size   = 14.0,
    },
    color   = colors.white,
    padding_left  = 6,
    padding_right = 4,
  },
  label = {
    font  = {
      family = settings.font.text,
      style  = "Semibold",
      size   = 12.0,
    },
    color   = colors.white,
    padding_left  = 4,
    padding_right = 6,
  },
  padding_left  = settings.paddings,
  padding_right = settings.paddings,
})
