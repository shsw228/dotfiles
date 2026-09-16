local sbar = require("sketchybar")

-- AeroSpace 連動イベント（aerospace.toml のコールバックと bridge から --trigger で発火）
sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "aerospace_focus_change")
sbar.add("event", "aerospace_mode_change")
-- volume.lua の click_script からミュート反映用に内部発火
sbar.add("event", "volume_state_refresh")

local styles = require("styles")

-- 左側の並び (左→右): workspace (一覧 + 現在地の用途名) | front_app | aerospace_mode
-- リングの土台はワークスペース item より先に追加して、数字の下のレイヤに置く
require("items.aerospace_ring_anchor")
require("items.aerospace")

-- ワークスペース群とアプリ情報群の面を離すためのダミー item。どちらの bracket にも入れない。
sbar.add("item", "left_group_gap", {
  position = "left",
  width = styles.group_gap,
  padding_left  = 0,
  padding_right = 0,
  icon  = { drawing = false, padding_left = 0, padding_right = 0 },
  label = { drawing = false, padding_left = 0, padding_right = 0 },
  background = { drawing = false },
})

require("items.front_app")
require("items.aerospace_mode")

-- スライドするインジケータは左グループの最後に置く。負 padding は後続 item の
-- advance を増やしてしまうので、後ろに item を置けない (詳細は同ファイル)。
require("items.aerospace_indicator")

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

-- スリープ復帰時に AeroSpace を組み直させるイベントハンドラ (非表示item)
require("items.wake")

-- システム外観 (Dark/Light) 切り替えで再読み込みするハンドラ (非表示item)
require("items.theme")

-- 中央は notch ディスプレイで items が notch を挟んで分割されるので bracket に
-- できない (面は date/clock 側の item で持つ)。
local displays = require("displays")

sbar.add("bracket", "left_bracket", {
  "front_app", "aerospace_mode",
}, {
  blur_radius = styles.bracket.blur_radius,
  background = styles.bracket.background,
})

local ext = displays.external_indices[1]
if ext then
  sbar.add("bracket", "right_bracket_external", {
    "media", "system", "audio", "input_source", "wifi", "battery",
  }, {
    blur_radius = styles.bracket.blur_radius,
    background = styles.bracket.background,
    associated_display = ext,
  })
end
if displays.builtin_index then
  -- MacBook 側: CPU/RAM 無し、audio/media は minimum item
  sbar.add("bracket", "right_bracket_builtin", {
    "media_simple", "audio_simple", "input_source", "wifi", "battery",
  }, {
    blur_radius = styles.bracket.blur_radius,
    background = styles.bracket.background,
    associated_display = displays.builtin_index,
  })
end

-- 起動直後は誰も --trigger を投げていないので、一度だけ自分で state を引く。
-- AeroSpace には state stream が無く、更新はコールバック契機でしか来ない。
sbar.exec(os.getenv("HOME") .. "/.config/sketchybar/plugins/aerospace_bridge.sh workspace")
