local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

local clock = sbar.add("item", "clock", {
  position = "right",
  icon = {
    string = icons.clock,
    color  = colors.yellow,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    color = colors.white,
    padding_right = 8,
  },
  background = {
    color = colors.bg1,
    height = 22,
    corner_radius = 6,
  },
  update_freq = 30,
})

clock:subscribe({ "routine", "forced", "system_woke" }, function()
  clock:set({ label = { string = os.date("%m/%d (%a) %H:%M") } })
end)

clock:set({ label = { string = os.date("%m/%d (%a) %H:%M") } })
