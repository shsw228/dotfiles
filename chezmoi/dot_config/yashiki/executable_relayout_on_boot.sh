#!/bin/sh
# Mac 再起動直後の余分な上部 padding を解消するための relayout ウォッチャー。
#
# 背景:
#   ~/.config/yashiki/init は sketchybar 用に上部 48px を outer-gap で確保する。
#   一方 macOS メニューバーは自動非表示 (_HIHideMenuBar) 設定にしているが、
#   Mac 起動直後はこの自動非表示が効くまでの間だけメニューバーが領域を確保し、
#   yashiki がその狭いフレームを基準に outer-gap を足してしまう。結果として
#   上部に「メニューバー分 + 48px」の余分な padding が残る（yashiki を手動で
#   再起動すると正しいフレームで組み直されて直る、という事象）。
#
# 対処:
#   メニューバーが確保する「画面上部インセット」を JXA(NSScreen) で監視し、
#   値が変化するたびに yashiki を組み直す。自動非表示が効いてインセットが
#   確定 (=しばらく変化しない) したら最終 retile して終了する。retile と
#   set-outer-gap は冪等なので、手動再起動時に走っても無害。
set -u

YASHIKI="/opt/homebrew/bin/yashiki"
[ -x "$YASHIKI" ] || YASHIKI="yashiki"

# main display の上部インセット (= メニューバーが確保している高さ) を返す。
# NSScreen.frame と visibleFrame の上辺の差分。メニューバー非表示なら ~0。
top_inset() {
  /usr/bin/osascript -l JavaScript <<'JXA' 2>/dev/null
ObjC.import('AppKit');
var s = $.NSScreen.mainScreen;
if (!s || s.isNil()) {
  '';
} else {
  var f = s.frame, v = s.visibleFrame;
  var inset = (f.origin.y + f.size.height) - (v.origin.y + v.size.height);
  Math.round(inset).toString();
}
JXA
}

relayout() {
  "$YASHIKI" set-outer-gap 48 12 12 12 2>/dev/null || true
  "$YASHIKI" retile 2>/dev/null || true
}

prev=""
stable=0
i=0
# 上限 ~20s (0.5s x 40)。それまでにインセットが確定しなくても最後に必ず確定させる。
while [ "$i" -lt 40 ]; do
  cur=$(top_inset)
  if [ -n "$cur" ]; then
    if [ "$cur" = "$prev" ]; then
      stable=$((stable + 1))
    else
      # インセットが動いた = メニューバー確保量が変化した。yashiki を組み直す。
      relayout
      stable=0
      prev="$cur"
    fi
    # 約2s 変化なしなら確定とみなして抜ける
    [ "$stable" -ge 4 ] && break
  fi
  sleep 0.5
  i=$((i + 1))
done

# 最終確定
relayout
