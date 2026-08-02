#!/bin/bash
# ディスプレイ構成変更に yashiki と sketchybar を追従させる常駐ウォッチャー。
#
# ■ なぜ必要か
#   yashiki がディスプレイ矩形を読み直すのは次の2箇所だけ (v0.15.2 / master 9a22f98):
#     - daemon 起動時            app.rs:434  -> sync_all
#     - CGDisplay 再構成コールバック app.rs:894 -> handle_display_change
#   `retile` / `set-outer-gap` は Effect::Retile を出すだけで get_all_displays() を
#   呼ばない。つまり yashiki 側のディスプレイキャッシュが古くなった場合、CLI からは
#   絶対に直せず daemon 再起動しかない（手動再起動で直るのはこのため）。
#   さらに再構成コールバックは kCGDisplayBeginConfigurationFlag の「変更前」呼び出しも
#   フィルタせず、デバウンスも無いため、確定前の座標でタイルし直すことがある。
#
# ■ 何をするか
#   1. yashiki subscribe --filter display でイベントを購読
#   2. 最後のイベントから QUIET_TICKS 秒静かになるまでデバウンス
#   3. yashiki の認識 (list-outputs) と OS の実体 (NSScreen) を突き合わせる
#      - 一致   -> キャッシュは正しい。set-outer-gap + retile で組み直す（軽い）
#      - 不一致 -> キャッシュが腐っていて retile では直らない。daemon を再起動する（重い）
#   4. sketchybar を --reload する
#      sketchybar 本体も抜き差しは検知するがバーの再配置までで、起動時の display 構成に
#      依存して組んだ item 構成 (notch_spacer 等) は作り直さない。--reload は
#      bar_manager_destroy + init + exec_config_file なので item ごと作り直せる。
#
#   旧 relayout_on_boot.sh (NSScreen の visibleFrame インセットを監視) は前提が誤りだった。
#   yashiki は CGDisplayBounds しか見ておらず visibleFrame を一切参照しないため、
#   メニューバーの表示・非表示は yashiki の矩形を 1px も変えない。監視対象を
#   「yashiki の認識と OS の実体の突き合わせ」に置き換えたのがこのスクリプト。
#
#   旧 sketchybar 側 display_watcher.sh の役割もここへ統合した。両方が同じイベントで
#   独立に動くと sketchybar が二重に作り直されるため、直列化している。

set -u

YASHIKI="/opt/homebrew/bin/yashiki"
[ -x "$YASHIKI" ] || YASHIKI="yashiki"
SKETCHYBAR="/opt/homebrew/bin/sketchybar"

# init の set-outer-gap と同じ値を保つこと（init が正、ここは再適用用の写し）
OUTER_GAP="48 12 12 12"

# デバウンス: 1 秒 tick で QUIET_TICKS 回続けて無イベントなら確定とみなす
QUIET_TICKS=3
# ログイン直後は構成が動いている最中なので、初回判定までこれだけ待つ
BOOT_DELAY=3
# 再起動ループ防止: 前回の再起動からこの秒数以内は再起動せず retile で妥協する
RESTART_COOLDOWN=60

LOG="${TMPDIR:-/tmp}/yashiki_display_watcher.log"
STAMP="${TMPDIR:-/tmp}/yashiki_display_watcher.restart"
log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG" 2>/dev/null || true; }
: >"$LOG" 2>/dev/null || true

SELF_PID=$$
# 多重起動防止: yashiki 再起動で init が新しい watcher を spawn するため、
# 古い自分を必ず畳む。再起動を仕掛けた側が kill されても困らないよう、
# restart_yashiki() は切り離したプロセスで実行する。
for pid in $(pgrep -f 'yashiki/display_watcher\.sh$' 2>/dev/null); do
  [ "$pid" = "$SELF_PID" ] && continue
  kill "$pid" 2>/dev/null
done

log "start pid=$SELF_PID"

# OS 実体の署名: "<displayID>:<幅>x<高さ>" を ID 順に並べたもの
os_signature() {
  /usr/bin/osascript -l JavaScript <<'JXA' 2>/dev/null
ObjC.import('AppKit');
var out = [];
var screens = $.NSScreen.screens;
for (var i = 0; i < screens.count; i++) {
  var s = screens.objectAtIndex(i);
  var num = s.deviceDescription.objectForKey('NSScreenNumber');
  var f = s.frame;
  out.push(num.intValue + ':' + Math.round(f.size.width) + 'x' + Math.round(f.size.height));
}
out.sort().join(' ');
JXA
}

# yashiki 認識の署名: list-outputs の "2: NAME [2560x1080 @ (0,0)] (main) *" を同形式へ
yashiki_signature() {
  "$YASHIKI" list-outputs 2>/dev/null | awk '
    /^[0-9]+:/ {
      id = $1; sub(/:$/, "", id)
      if (match($0, /\[[0-9]+x[0-9]+ /)) {
        print id ":" substr($0, RSTART + 1, RLENGTH - 2)
      }
    }' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ *$//'
}

reload_sketchybar() {
  [ -x "$SKETCHYBAR" ] || return 0
  "$SKETCHYBAR" --reload >/dev/null 2>&1 || true
}

# 再起動は切り離して実行する。この watcher は新 init が spawn する watcher に
# kill されるので、インラインで実行すると quit と open の間で死ぬ危険がある。
restart_yashiki() {
  date +%s >"$STAMP" 2>/dev/null || true
  nohup /bin/sh -c "
    '$YASHIKI' quit >/dev/null 2>&1 || true
    sleep 1
    /usr/bin/open -a Yashiki >/dev/null 2>&1 || true
  " >/dev/null 2>&1 &
}

restart_allowed() {
  local last
  [ -f "$STAMP" ] || return 0
  last=$(cat "$STAMP" 2>/dev/null) || return 0
  case "$last" in ''|*[!0-9]*) return 0 ;; esac
  [ $(( $(date +%s) - last )) -ge "$RESTART_COOLDOWN" ]
}

# $1: "boot" なら sketchybar reload を省く（init 側が直後に --reload するため）
settle() {
  local phase os_sig ya_sig
  phase="$1"
  os_sig=$(os_signature)
  ya_sig=$(yashiki_signature)

  if [ -z "$os_sig" ] || [ -z "$ya_sig" ]; then
    log "$phase: 署名取得に失敗 (os=[$os_sig] yashiki=[$ya_sig]) -> 何もしない"
    return
  fi

  if [ "$os_sig" = "$ya_sig" ]; then
    log "$phase: 一致 [$os_sig] -> set-outer-gap + retile"
    # shellcheck disable=SC2086
    "$YASHIKI" set-outer-gap $OUTER_GAP >/dev/null 2>&1 || true
    "$YASHIKI" retile >/dev/null 2>&1 || true
    [ "$phase" = "boot" ] || reload_sketchybar
    return
  fi

  if restart_allowed; then
    log "$phase: 不一致 yashiki=[$ya_sig] os=[$os_sig] -> yashiki 再起動"
    restart_yashiki
  else
    # 再起動直後にまだ食い違う場合。ループを避けて retile で妥協する。
    log "$phase: 不一致だが cooldown 中 yashiki=[$ya_sig] os=[$os_sig] -> retile のみ"
    "$YASHIKI" retile >/dev/null 2>&1 || true
    [ "$phase" = "boot" ] || reload_sketchybar
  fi
}

sleep "$BOOT_DELAY"
settle boot

while true; do
  pending=0
  quiet=0

  while true; do
    IFS= read -r -t 1 line
    rc=$?

    if [ "$rc" -eq 0 ]; then
      [ -z "$line" ] && continue
      evtype=$(printf '%s' "$line" | jq -r '.type' 2>/dev/null)
      case "$evtype" in
        display_added|display_removed|display_updated)
          log "event: $evtype"
          pending=1
          quiet=0
          ;;
      esac
    elif [ "$rc" -gt 128 ]; then
      # read のタイムアウト = 1 秒無音
      if [ "$pending" -eq 1 ]; then
        quiet=$((quiet + 1))
        if [ "$quiet" -ge "$QUIET_TICKS" ]; then
          settle event
          pending=0
          quiet=0
        fi
      fi
    else
      # EOF: yashiki が落ちた等。購読し直す
      log "subscribe が切断された -> 再購読"
      break
    fi
  done < <("$YASHIKI" subscribe --filter display 2>/dev/null)

  sleep 2
done
