local sbar = require("sketchybar")
local colors = require("colors")
local settings = require("settings")

-- 主ディスプレイが上部に恒常的に確保している高さ。自動非表示なら 0、固定表示なら
-- その分。y_offset は画面上端からのオフセットなので、これを足さないと固定表示時に
-- バーがメニューバーの裏に潜る。
--
-- 値は display_watcher.sh が書く。ウォッチャーは yashiki の購読ペイロードから
--   inset = 可視.y - 物理.y
-- で導いており、ここで OS を見ると同じ値を別経路で二重に持つことになる。食い違った
-- ときに原因を追えなくなるので、幾何情報の出どころは yashiki 一本に揃える。
--
-- ウォッチャーはこのファイルを書いてから --reload するので、読む時点で最新。
-- ウォッチャー未起動時（初回ブートで yashiki より sketchybar が先に上がった等）は
-- ファイルが無いので 0 を返す。yashiki の init 末尾の --reload で入り直る。
local function menu_bar_inset()
  local f = io.open(os.getenv("HOME") .. "/.cache/yashiki/bar_inset", "r")
  if not f then return 0 end
  local v = f:read("*l")
  f:close()
  return tonumber(v) or 0
end

sbar.bar({
  height    = settings.bar.height,
  color     = colors.bar.bg,
  border_color = colors.bar.border,
  border_width = 0,
  -- y_offset で画面上端からのオフセット。notch handling は notch_width 側で制御。
  margin    = 12,
  y_offset  = 8 + menu_bar_inset(),
  corner_radius = settings.bar.corner_radius,
  -- notch display (MacBook): notch_width 分を中央から避けて items を左右に振る
  notch_width = 220,
  -- margin で画面端〜バー間 = 12px に揃える。bar.padding は加算されるので 0 にして
  -- yashiki outer-gap(12) と視覚的に一致させる。
  padding_left  = 0,
  padding_right = 0,
  topmost   = "window",
  sticky    = true,
  shadow    = false,
  display   = "all",
})
