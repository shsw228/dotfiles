local sbar = require("sketchybar")
local colors = require("colors")

-- 中央配置。notch ディスプレイではnotchの左側に出る
local date = sbar.add("item", "date", {
  position = "center",
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = {
    color = colors.white,
    padding_left  = 8,
    padding_right = 8,
  },
  update_freq = 30,
})

local function refresh()
  date:set({ label = { string = os.date("%m/%d (%a)") } })
end

date:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
