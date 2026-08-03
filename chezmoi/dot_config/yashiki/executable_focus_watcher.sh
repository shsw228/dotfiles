#!/bin/bash
# yashiki のフォーカス状態に反応する常駐ウォッチャー。
#
#   1. JankyBorders の枠色を floating / tiling で切り替える
#   2. フォーカスが宙に浮いたら yashiki に回復させる
#
# yashiki にイベントフックは無い (exec は即時実行) ので、状態を知る手段は
# subscribe だけ。init から背景で起動し、yashiki と同じプロセスグループに入る。
#
# sketchybar とは無関係なので yashiki_bridge.sh には置かない。

set -u

# CLI は稼働中の daemon と同じバイナリを使う。サブコマンドは CLI 側でパースされて
# から IPC に載るため、CLI と daemon の版が食い違うと弾かれる。
# 引数なしか start のときだけ daemon とみなす (CLI 呼び出しを拾わないため)。
resolve_yashiki() {
  local running
  running=$(ps -axo args 2>/dev/null \
    | awk '$1 ~ /\/yashiki$/ && (NF == 1 || $2 == "start") { print $1; exit }')
  if [ -n "$running" ] && [ -x "$running" ]; then
    printf '%s' "$running"
    return
  fi
  if [ -x /opt/homebrew/bin/yashiki ]; then
    printf '%s' /opt/homebrew/bin/yashiki
  else
    printf '%s' yashiki
  fi
}

YASHIKI=$(resolve_yashiki)
BORDERS="/opt/homebrew/bin/borders"

# 旧 AeroSpace 設定の floating=オレンジ / tiling=白 を踏襲
BORDER_FLOATING=0xfff5a97f
BORDER_TILING=0xffe1e3e4
BORDER_INACTIVE=0xff494d64

RUNDIR="${TMPDIR:-/tmp}"
LOCK="$RUNDIR/yashiki_focus_watcher.pid"
BACKOFF_MAX=60

# 多重起動防止。pgrep はディレクトリサービスが壊れていると無言失敗するため使わない。
if [ -f "$LOCK" ]; then
  old=$(cat "$LOCK" 2>/dev/null)
  case "$old" in
    ''|*[!0-9]*) ;;
    *)
      if [ "$old" != "$$" ] && kill -0 "$old" 2>/dev/null; then
        kill "$old" 2>/dev/null
        sleep 1
      fi
      ;;
  esac
fi
printf '%s\n' "$$" >"$LOCK" 2>/dev/null || true

cleanup() {
  [ -f "$LOCK" ] && [ "$(cat "$LOCK" 2>/dev/null)" = "$$" ] && rm -f "$LOCK"
  exit 0
}
trap cleanup EXIT INT TERM

# メニューが開いているか。layer 101 は kCGPopUpMenuWindowLevel で、メニューバーの
# メニューもコンテキストメニューもここに出る。yashiki 本体が auto-raise の抑止に
# 使っているのと同じ基準。
#
# ObjC.deepUnwrap は CGWindowListCopyWindowInfo の戻り値を解けないので
# bindFunction で直接叩く。64ms かかるが、呼ぶのはフォーカス失効時だけ。
popup_menu_open() {
  /usr/bin/osascript -l JavaScript <<'JXA' 2>/dev/null | grep -q '^1$'
ObjC.bindFunction('CGWindowListCopyWindowInfo', ['id', ['unsigned int', 'unsigned int']]);
var list = $.CGWindowListCopyWindowInfo(1, 0);
var found = 0;
for (var i = 0; i < $.CFArrayGetCount(list); i++) {
  var d = ObjC.castRefToObject($.CFArrayGetValueAtIndex(list, i));
  var lv = d.objectForKey('kCGWindowLayer');
  if (!lv.isNil() && lv.intValue >= 101) { found = 1; break; }
}
String(found);
JXA
}

apply_borders() {  # $1=floating (true/false)
  [ -x "$BORDERS" ] || return 0
  local active
  if [ "$1" = "true" ]; then active="$BORDER_FLOATING"; else active="$BORDER_TILING"; fi
  "$BORDERS" active_color="$active" inactive_color="$BORDER_INACTIVE" width=5.0 \
    >/dev/null 2>&1 </dev/null &
}

# フォーカスが宙に浮いたら回復させる。放置すると alt-hjkl 等が効かなくなる。
#
# メニュー表示中は触らない。フォーカスを動かすとメニューを出しているアプリが
# 非アクティブになり、メニューが閉じてしまう。ウィンドウを持たないメニューバー
# 常駐アプリでは、メニューを開いた時点でフォーカス失効として流れてくる。
recover_focus() {
  popup_menu_open && return 0
  "$YASHIKI" window-focus next >/dev/null 2>&1 </dev/null &
}

# window_focused は window_id しか載せないので、floating なウィンドウの id 集合を
# 持っておく。フォーカスは頻繁に動くので、そのたびに list-windows を叩かない。
# bash 3.2 に declare -A は無いため空白区切りの文字列で持つ。
FLOATING=" "

floating_set() {  # $1=id  $2=true/false
  FLOATING=${FLOATING// $1 / }
  [ "$2" = "true" ] && FLOATING="$FLOATING$1 "
  return 0
}

is_floating() {  # $1=id
  case "$FLOATING" in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

subscribe_once() {
  local line type wid focused
  "$YASHIKI" subscribe --snapshot --filter focus,window 2>/dev/null </dev/null \
  | while IFS= read -r line; do
      [ -z "$line" ] && continue
      type=$(printf '%s' "$line" | jq -r '.type' 2>/dev/null)
      case "$type" in
        snapshot)
          FLOATING=" "
          while IFS= read -r wid; do
            [ -n "$wid" ] && FLOATING="$FLOATING$wid "
          done < <(printf '%s' "$line" | jq -r '.windows[]? | select(.is_floating) | .id' 2>/dev/null)
          wid=$(printf '%s' "$line" | jq -r '.focused_window_id // empty' 2>/dev/null)
          if [ -n "$wid" ] && is_floating "$wid"; then apply_borders true; else apply_borders false; fi
          ;;
        window_focused)
          wid=$(printf '%s' "$line" | jq -r '.window_id // "null"' 2>/dev/null)
          if [ "$wid" = "null" ] || [ "$wid" = "0" ] || [ -z "$wid" ]; then
            recover_focus
          elif is_floating "$wid"; then
            apply_borders true
          else
            apply_borders false
          fi
          ;;
        window_created|window_updated)
          wid=$(printf '%s' "$line" | jq -r '.window.id' 2>/dev/null)
          floating_set "$wid" "$(printf '%s' "$line" | jq -r '.window.is_floating' 2>/dev/null)"
          if [ "$(printf '%s' "$line" | jq -r '.window.is_focused' 2>/dev/null)" = "true" ]; then
            if is_floating "$wid"; then apply_borders true; else apply_borders false; fi
          fi
          ;;
        window_destroyed)
          wid=$(printf '%s' "$line" | jq -r '.window_id' 2>/dev/null)
          floating_set "$wid" false
          focused=$("$YASHIKI" focused-window 2>/dev/null)
          if [ -z "$focused" ] || [ "$focused" = "$wid" ]; then
            recover_focus
          fi
          ;;
      esac
    done
}

backoff=2
while true; do
  if "$YASHIKI" list-outputs >/dev/null 2>&1 </dev/null; then
    backoff=2
    subscribe_once
  fi
  sleep "$backoff"
  backoff=$((backoff * 2))
  [ "$backoff" -gt "$BACKOFF_MAX" ] && backoff="$BACKOFF_MAX"
done
