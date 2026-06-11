local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

local mode = sbar.add("item", "window.mode", {
  position = "left",
  icon = {
    string = icons.layout.tiling,
    color  = colors.blue,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    string = "tiling",
    color  = colors.white,
    padding_right = 8,
  },
  background = {
    color = colors.bg1,
    height = 22,
    corner_radius = 6,
  },
  updates = true,
})

local last_state = nil
local function apply(floating)
  local resolved = floating and "floating" or "tiling"
  if resolved == last_state then return end
  last_state = resolved
  if floating then
    mode:set({
      icon  = { string = icons.layout.floating, color = colors.orange },
      label = { string = "floating" },
    })
  else
    mode:set({
      icon  = { string = icons.layout.tiling, color = colors.blue },
      label = { string = "tiling" },
    })
  end
end

mode:subscribe("yashiki_focus_change", function(env)
  apply(env.FLOAT == "true")
end)
