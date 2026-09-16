local sbar = require("sketchybar")

-- スリープ復帰直後は sketchybar が持っているワークスペース状態が古いことがある。
-- AeroSpace には retile に当たるコマンドが無く、状態はコールバック契機でしか
-- 流れてこないので、bridge を一度叩いて引き直す。
-- 専用アイテムを作って drawing=off にしておけば、見た目には影響せずイベントだけ拾える。
local BRIDGE = os.getenv("HOME") .. "/.config/sketchybar/plugins/aerospace_bridge.sh"

local wake = sbar.add("item", "wake_handler", {
  drawing = false,
  updates = true,
})

wake:subscribe("system_woke", function()
  sbar.exec(BRIDGE .. " workspace &")
end)
