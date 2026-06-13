local sbar = require("sketchybar")
local colors = require("colors")
local icons = require("icons")

-- フロントアプリ名 + 現在ウィンドウのレイアウト状態 (tiling / floating) を1アイテムに統合表示
local front = sbar.add("item", "front_app", {
  position = "left",
  icon = {
    string = icons.layout.tiling,
    color  = colors.blue,
    padding_left  = 8,
    padding_right = 4,
  },
  label = {
    string = "",
    color  = colors.white,
    padding_left  = 4,
    padding_right = 8,
    max_chars = 28,
    align = "left",
  },
})

local function set_layout(floating)
  if floating then
    front:set({ icon = { string = icons.layout.floating, color = colors.orange } })
  else
    front:set({ icon = { string = icons.layout.tiling, color = colors.blue } })
  end
end

front:subscribe("front_app_switched", function(env)
  front:set({ label = { string = env.INFO or "" } })
end)

front:subscribe("yashiki_focus_change", function(env)
  set_layout(env.FLOAT == "true")
end)
