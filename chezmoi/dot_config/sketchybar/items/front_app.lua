local sbar = require("sketchybar")
local colors = require("colors")

local front_app = sbar.add("item", "front_app", {
  position = "left",
  icon = { drawing = false },
  label = {
    color = colors.white,
    padding_left  = 8,
    padding_right = 8,
    max_chars = 32,
  },
  background = {
    color = colors.transparent,
    height = 22,
  },
})

front_app:subscribe("front_app_switched", function(env)
  front_app:set({ label = { string = env.INFO or "" } })
end)
