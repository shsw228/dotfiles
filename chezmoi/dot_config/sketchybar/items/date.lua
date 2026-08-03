local sbar = require("sketchybar")
local colors = require("colors")
local styles = require("styles")

-- 中央配置。notch ディスプレイではnotchの左側に出る。
-- 中央は notch で左右に割れるため bracket にできないので、面は item 単位で持つ。
local date = sbar.add("item", "date", {
  position = "center",
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = {
    color = colors.fg,
    padding_left  = 8,
    padding_right = 8,
  },
  blur_radius = styles.pill.blur_radius,
  background = styles.pill.background,
  update_freq = 30,
})

local function refresh()
  date:set({ label = { string = os.date("%m/%d (%a)") } })
end

date:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
