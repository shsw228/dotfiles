local sbar = require("sketchybar")
local colors = require("colors")

-- macOS メニューバーが恒常的に確保している上部の高さ。
-- 自動非表示なら 0、固定表示なら 31。sketchybar の y_offset は画面上端からの
-- オフセットなので、これを足さないと固定表示時にバーがメニューバーの裏に潜る。
--
-- NSScreen.frame と visibleFrame の上辺の差で測る。yashiki 側 (macos/display.rs の
-- detect_menu_bar_heights) と同じ基準なので値が揃う。
--
-- CGWindowList でメニューバー窓を探す方法は使わないこと。自動非表示時に「今出て
-- いるか」を拾ってしまうだけでなく、固定表示で領域を確保している状態でも窓が
-- リストに現れないことがある（実測で visibleFrame が 31 を返しているのに
-- layer 24 の窓が 0 件だった）。
--
-- visibleFrame は長時間動くプロセスでは AppKit にキャッシュされるが、ここは
-- 設定読み込みのたびに osascript を起動する短命プロセスなので影響を受けない。
local function menu_bar_inset()
  local jxa = [[
ObjC.import('AppKit');
var s = $.NSScreen.mainScreen;
if (!s || s.isNil()) { '0'; } else {
  var f = s.frame, v = s.visibleFrame;
  String(Math.max(0, Math.round((f.origin.y + f.size.height) - (v.origin.y + v.size.height))));
}
]]
  local cmd = "/usr/bin/osascript -l JavaScript -e " .. string.format("%q", jxa) .. " 2>/dev/null"
  local pipe = io.popen(cmd)
  if not pipe then return 0 end
  local out = pipe:read("*a")
  pipe:close()
  return tonumber((out or ""):match("%d+")) or 0
end

sbar.bar({
  height    = 32,
  color     = colors.bar.bg,
  border_color = colors.bar.border,
  border_width = 0,
  -- y_offset で画面上端からのオフセット。notch handling は notch_width 側で制御。
  margin    = 12,
  y_offset  = 8 + menu_bar_inset(),
  corner_radius = 10,
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
