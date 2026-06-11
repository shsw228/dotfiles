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

local function refresh()
  sbar.exec(
    "aerospace list-windows --focused --format '%{window-layout}' 2>/dev/null",
    function(result)
      local layout = (result or ""):gsub("%s+", "")
      if layout == "floating" then
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
  )
end

mode:subscribe({ "front_app_switched", "aerospace_workspace_change", "window_focus" }, refresh)

refresh()
