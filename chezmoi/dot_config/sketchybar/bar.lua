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

-- 解決後の値。display_watcher.sh に渡すので名前を付けておく。
local bar_height   = settings.bar.height
local bar_y_offset = 8 + menu_bar_inset()

-- display_watcher.sh に解決後のバー位置を渡す。
--
-- ウォッチャーは gap.top を
--   gap.top = y_offset + height + WINDOW_MARGIN - inset
-- で出す。これを sketchybar --query bar から読むと、設定のロードが終わるまで返る
-- デフォルト値 (y_offset=0, height=25) を掴んでしまう。妥当な数値なので range
-- check では弾けず、安定して返るので「同じ値が2回」でも見分けられない。実際それで
-- gap.top が 0+25+8=33 になり、窓が 8+32+8=48 より 15px 上にずれていた。
--
-- ウォッチャーは --reload の前にこのファイルを消し、現れるのを待つ。存在すれば今
-- ロードされた設定が書いたものだと確定するので、時刻の比較が要らない。
-- 途中まで書けたものを読ませないよう、一時ファイルに書いてから rename する。
local function publish_bar_metrics()
  local dir  = os.getenv("HOME") .. "/.cache/yashiki"
  local path = dir .. "/bar_metrics"
  local tmp  = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then
    -- 初回ブートでは ~/.cache/yashiki がまだ無い
    os.execute("mkdir -p '" .. dir .. "'")
    f = io.open(tmp, "w")
    if not f then return end
  end
  f:write(string.format("%d %d\n", bar_y_offset, bar_height))
  f:close()
  os.rename(tmp, path)
end

publish_bar_metrics()

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
  -- yashiki outer-gap(12) と視覚的に一致させる。
  padding_left  = 0,
  padding_right = 0,
  topmost   = "window",
  sticky    = true,
  shadow    = false,
  display   = "all",
})
