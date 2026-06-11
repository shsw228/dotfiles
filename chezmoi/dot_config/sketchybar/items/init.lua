local sbar = require("sketchybar")

-- yashiki 連動イベント（bridge スクリプトから --trigger で発火）
sbar.add("event", "yashiki_workspace_change")
sbar.add("event", "yashiki_focus_change")
-- volume.lua の click_script からミュート反映用に内部発火
sbar.add("event", "volume_state_refresh")

require("items.yashiki")
require("items.mode")
require("items.front_app")

-- 右側 (反対側) のアイテムは追加順に右から左へ並ぶ
require("items.clock")
require("items.battery")
require("items.wifi")
require("items.volume")
require("items.audio_device")

-- yashiki state stream を購読するブリッジを起動
sbar.exec(os.getenv("HOME") .. "/.config/sketchybar/plugins/yashiki_bridge.sh &")
