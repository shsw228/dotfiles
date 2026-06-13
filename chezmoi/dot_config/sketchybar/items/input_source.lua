local sbar = require("sketchybar")
local colors = require("colors")

-- 入力ソースを判定して「あ」(日本語入力中) / 「A」(英字) を表示。
-- macism (laishulu/homebrew/macism) で現在のソースIDを取得して識別する。
local MACISM = "/opt/homebrew/bin/macism"

local input = sbar.add("item", "input_source", {
  position = "right",
  icon = { drawing = false, padding_left = 0, padding_right = 0 },
  label = {
    color = colors.white,
    padding_left  = 8,
    padding_right = 8,
    width = 18,
    align = "center",
    font = { family = "Monaspace Neon", style = "Bold", size = 13.0 },
  },
  update_freq = 1,
})

local function refresh()
  sbar.exec(MACISM .. " 2>/dev/null", function(result)
    local src = (result or ""):gsub("%s+$", "")
    local label, color
    if src:find("Japanese") then
      label, color = "あ", colors.orange
    else
      label, color = "A", colors.white
    end
    input:set({ label = { string = label, color = color } })
  end)
end

input:subscribe({ "routine", "forced", "system_woke" }, refresh)
refresh()
