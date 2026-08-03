local sbar = require("sketchybar")

-- yashiki 連動イベント（bridge / wrapper スクリプトから --trigger で発火）
sbar.add("event", "yashiki_workspace_change")
sbar.add("event", "yashiki_focus_change")
sbar.add("event", "yashiki_mode_change")
sbar.add("event", "yashiki_main_count_change")
-- volume.lua の click_script からミュート反映用に内部発火
sbar.add("event", "volume_state_refresh")

-- 左側の並び (左→右): tag | front_app | yashiki_mode | yashiki_main_count
require("items.yashiki")
require("items.front_app")
require("items.yashiki_mode")
require("items.yashiki_main_count")

-- 中央配置の並び (左→右): date → notch_spacer → clock → notch_balance
-- notch_spacer: MBP モデル検出から notch width を割り出し、その幅 + 余白を確保
-- notch_balance: date/clock の実描画幅差を sketchybar query で算出して埋める
require("items.date")
require("items.notch_spacer")
require("items.clock")
require("items.notch_balance")

-- 右側のアイテムは追加順に右から左へ並ぶ
-- 並び (右→左): battery (AC時非表示) | wifi | input_source | audio (volume統合) | system | media
require("items.battery")
require("items.wifi")
require("items.input_source")
require("items.volume")
require("items.system")
require("items.media")

-- スリープ復帰時に yashiki を retile させるイベントハンドラ (非表示item)
require("items.wake")

-- 右側のグループを bracket でまとめる。中央は notch ディスプレイで items が
-- notch を挟んで分割されるので、bracket でまとめると分離を妨げる→ 中央は素のまま。
local displays = require("displays")
local styles = require("styles")

local bracket_bg = styles.bracket_bg

local ext = displays.external_indices[1]
if ext then
  sbar.add("bracket", "right_bracket_external", {
    "media", "system", "audio", "input_source", "wifi", "battery",
  }, {
    background = bracket_bg,
    associated_display = ext,
  })
end
if displays.builtin_index then
  -- MacBook 側: CPU/RAM 無し、audio/media は minimum item
  sbar.add("bracket", "right_bracket_builtin", {
    "media_simple", "audio_simple", "input_source", "wifi", "battery",
  }, {
    background = bracket_bg,
    associated_display = displays.builtin_index,
  })
end

-- yashiki state stream を購読するブリッジを起動
sbar.exec(os.getenv("HOME") .. "/.local/bin/yashiki-bridge &")
-- ディスプレイ構成変更時の作り直しは ~/.config/yashiki/display_watcher.sh に集約した。
-- yashiki 側で retile と直列化する必要があり、両方が独立に動くと二重に作り直される。
