local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")

-- 主ディスプレイが上部に恒常的に確保している高さ。自動非表示なら 0、固定表示なら
-- その分。y_offset は画面上端からのオフセットなので、これを足さないと固定表示時に
-- バーがメニューバーの裏に潜る。
--
-- yashiki 時代は display_watcher.sh が yashiki の購読ペイロードから
--   inset = 可視.y - 物理.y
-- を導いて ~/.cache/yashiki/bar_inset に書いていた。AeroSpace には同等の
-- ジオメトリ通知が無いので、OS の設定を直接見る。
--
-- run_onchange_20 がメニューバーを自動非表示にしているので通常は 0 になる。
-- 手動で戻したときにバーが潜らないよう、固定表示ぶんも見ておく。
local MENU_BAR_HEIGHT = 24

local function menu_bar_inset()
  local f = io.popen("defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null")
  if not f then return MENU_BAR_HEIGHT end
  local v = f:read("*l")
  f:close()
  if v == "1" then return 0 end
  return MENU_BAR_HEIGHT
end

local bar_height   = settings.bar.height
local bar_y_offset = 8 + menu_bar_inset()

sbar.bar({
  height    = bar_height,
  color     = colors.bar.bg,
  border_color = colors.bar.border,
  border_width = 0,
  -- y_offset で画面上端からのオフセット。notch handling は notch_width 側で制御。
  margin    = 12,
  y_offset  = bar_y_offset,
  corner_radius = settings.bar.corner_radius,
  -- notch display (MacBook): notch_width 分を中央から避けて items を左右に振る
  notch_width = 220,
  -- margin で画面端〜バー間 = 12px に揃える。bar.padding は加算されるので 0 にして
  -- AeroSpace の outer gap(12) と視覚的に一致させる。
  padding_left  = 0,
  padding_right = 0,
  topmost   = "window",
  sticky    = true,
  shadow    = false,
  display   = "all",
})
