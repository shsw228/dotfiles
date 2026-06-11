local sbar = require("sketchybar")

-- aerospace ワークスペース切替時にバー側へ流すカスタムイベント
sbar.add("event", "aerospace_workspace_change")

require("items.aerospace")
require("items.mode")
require("items.front_app")

-- 右側 (反対側) のアイテムは追加順に右から左へ並ぶ
require("items.clock")
require("items.battery")
require("items.wifi")
require("items.volume")
