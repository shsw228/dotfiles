local sbar = require("sketchybar")

-- yashiki 連動イベント（bridge スクリプトから --trigger で発火）
sbar.add("event", "yashiki_workspace_change")
sbar.add("event", "yashiki_focus_change")
-- volume.lua の click_script からミュート反映用に内部発火
sbar.add("event", "volume_state_refresh")

require("items.yashiki")
require("items.front_app")

-- 中央配置 (notch displayでは notch を挟んで左右に分割される)
require("items.date")
require("items.clock")

-- 右側のアイテムは追加順に右から左へ並ぶ
-- 並び (右→左): battery (AC時非表示) | wifi | input_source | audio (volume統合) | system | media
require("items.battery")
require("items.wifi")
require("items.input_source")
require("items.volume")
require("items.system")
require("items.media")

-- 中央 / 右側 のグループを bracket でまとめてブロック化
local bracket_bg = {
  color = 0x99000000,  -- 60% 黒。各ブロックが独立して見えるよう存在感のある背景
  corner_radius = 8,
  height = 28,
  border_width = 0,
}

sbar.add("bracket", "center_bracket", { "date", "clock" }, {
  background = bracket_bg,
})

sbar.add("bracket", "right_bracket", {
  "media",
  "system",
  "audio",
  "input_source",
  "wifi",
  "battery",
}, {
  background = bracket_bg,
})

-- yashiki state stream を購読するブリッジを起動
sbar.exec(os.getenv("HOME") .. "/.config/sketchybar/plugins/yashiki_bridge.sh &")
