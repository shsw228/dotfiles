local sbar = require("sketchybar")
local settings = require("settings")

local YASHIKI = settings.paths.yashiki

-- スリープ復帰直後に yashiki の状態がおかしいことがあるので retile を投げる。
-- 専用アイテムを作って drawing=off にしておけば、見た目には影響せずイベントだけ拾える。
local wake = sbar.add("item", "wake_handler", {
  drawing = false,
  updates = true,
})

wake:subscribe("system_woke", function()
  sbar.exec(YASHIKI .. " retile 2>/dev/null &")
end)
