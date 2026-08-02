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
#   3. yashiki が認識しているディスプレイ ID の集合と、OS の実体を突き合わせる
#      - 一致   -> キャッシュは正しい。set-outer-gap + retile で組み直す（軽い）
#      - 不一致 -> キャッシュが腐っていて retile では直らない。daemon を再起動する（重い）
#   4. sketchybar を --reload する
#      sketchybar 本体も抜き差しは検知するがバーの再配置までで、起動時の display 構成に
#      依存して組んだ item 構成 (notch_spacer 等) は作り直さない。--reload は
#      bar_manager_destroy + init + exec_config_file なので item ごと作り直せる。
#
# ■ 突き合わせに解像度を使わないこと
#   list-outputs の矩形はメニューバーの表示状態で変わる。実測:
#     メニューバー非表示: 2: DELL U4025QW [2560x1080 @ (0,0)]
#     メニューバー表示  : 2: DELL U4025QW [2560x1050 @ (0,30)]
#   一方 NSScreen.frame は常に 2560x1080 を返す。解像度で比較すると
#   メニューバーが出ているだけで「不一致」と誤判定し、yashiki を無駄に再起動する。
#   構成が変わったかどうかは ID の集合だけで判定する。解像度・配置の変更は
#   display イベント自体が拾うので、判定材料にする必要がない。
#
#   旧 relayout_on_boot.sh (NSScreen の visibleFrame インセットを監視) は前提が誤りだった。
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
BOOT_DELAY=5
# 再起動ループ防止: 前回の再起動からこの秒数以内は再起動せず retile で妥協する
RESTART_COOLDOWN=120
# 購読が失敗し続けたときのバックオフ上限（秒）
BACKOFF_MAX=60

RUNDIR="${TMPDIR:-/tmp}"
LOG="$RUNDIR/yashiki_display_watcher.log"
STAMP="$RUNDIR/yashiki_display_watcher.restart"
LOCK="$RUNDIR/yashiki_display_watcher.pid"

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG" 2>/dev/null || true; }

# 多重起動防止。pgrep はディレクトリサービスが壊れていると
# "Cannot get process list" で無言失敗するため使わない（実際にそれで
# ウォッチャーが多重起動した）。kill -0 で生存確認できる PID ファイルを使う。
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

# ログは追記しつつ肥大化を防ぐ（購読失敗が続くと行数が伸びるため）
if [ -f "$LOG" ] && [ "$(wc -l <"$LOG" 2>/dev/null || echo 0)" -gt 500 ]; then
  : >"$LOG" 2>/dev/null || true
fi

SUB_PID=""

# 購読を確実に畳む。
# bash のプロセス置換はサブシェルを 1 段挟むため、$! に入るのはそのサブシェルで、
# 実体の `yashiki subscribe` はさらにその子になる。サブシェルだけ kill すると
# 孫が親を失って残り続けるので、子も明示的に落とす。
# pgrep/pkill はディレクトリサービスが壊れると無言失敗するので ps で辿る。
kill_subscription() {  # $1 に nowait を渡すと wait を省く（trap 内でのハング回避）
  [ -n "$SUB_PID" ] || return 0
  ps -axo pid,ppid 2>/dev/null | awk -v p="$SUB_PID" '$2 == p { print $1 }' \
    | while read -r c; do kill "$c" 2>/dev/null; done
  kill "$SUB_PID" 2>/dev/null
  [ "${1:-}" = "nowait" ] || wait "$SUB_PID" 2>/dev/null
  SUB_PID=""
}

cleanup() {
  kill_subscription nowait
  [ -f "$LOCK" ] && [ "$(cat "$LOCK" 2>/dev/null)" = "$$" ] && rm -f "$LOCK"
  exit 0
}
trap cleanup EXIT INT TERM

log "start pid=$$"

# OS 実体のディスプレイ ID 集合
os_ids() {
  /usr/bin/osascript -l JavaScript <<'JXA' 2>/dev/null
ObjC.import('AppKit');
var out = [];
var screens = $.NSScreen.screens;
for (var i = 0; i < screens.count; i++) {
  var s = screens.objectAtIndex(i);
  out.push(s.deviceDescription.objectForKey('NSScreenNumber').intValue);
}
out.map(Number).sort(function (a, b) { return a - b; }).join(' ');
JXA
}

# yashiki が認識しているディスプレイ ID 集合
# list-outputs: "2: DELL U4025QW [2560x1050 @ (0,30)] (main) *"
yashiki_ids() {
  "$YASHIKI" list-outputs 2>/dev/null \
    | awk '/^[0-9]+:/ { id = $1; sub(/:$/, "", id); print id }' \
    | sort -n | tr '\n' ' ' | sed 's/ *$//'
}

# 直近に確定したディスプレイ ID 集合。sketchybar を作り直すかの判断に使う。
LAST_IDS=""

# sketchybar の item 構成はディスプレイ構成に依存するので、構成が変わったときだけ
# 作り直す。--reload は bar_manager_destroy からの完全な再構築でバーが一瞬消えるため、
# 解像度・配置だけが動いた回まで巻き込むと無駄にちらつく。
# （抜き差し 1 回で display_updated が 10 回以上飛ぶので、毎回 reload すると実害が出る）
reload_sketchybar() {
  [ -x "$SKETCHYBAR" ] || return 0
  "$SKETCHYBAR" --reload >/dev/null 2>&1 </dev/null || true
}

maybe_reload_sketchybar() {
  if [ "$1" = "$LAST_IDS" ]; then
    log "  ディスプレイ構成は不変 -> sketchybar reload は省略"
    return 0
  fi
  reload_sketchybar
}

# 再起動は切り離して実行する。このウォッチャーは新 init が spawn する
# ウォッチャーに kill されるので、インラインだと quit と open の間で死ぬ危険がある。
restart_yashiki() {
  date +%s >"$STAMP" 2>/dev/null || true
  nohup /bin/sh -c "
    '$YASHIKI' quit >/dev/null 2>&1 || true
    sleep 1
    /usr/bin/open -a Yashiki >/dev/null 2>&1 || true
  " >/dev/null 2>&1 </dev/null &
}

restart_allowed() {
  local last
  [ -f "$STAMP" ] || return 0
  last=$(cat "$STAMP" 2>/dev/null) || return 0
  case "$last" in ''|*[!0-9]*) return 0 ;; esac
  [ $(( $(date +%s) - last )) -ge "$RESTART_COOLDOWN" ]
}

# $1: フェーズ名。"boot" のときは sketchybar reload と daemon 再起動を行わない。
#     ログイン直後は構成が確定しておらず、ここで再起動すると
#     「再起動 -> init -> 新ウォッチャー -> また不一致」のループを招く。
#     本当に構成がズレていれば直後に CGDisplay 再構成イベントが飛ぶので、
#     event フェーズで拾えばよい。
settle() {
  local phase os_list ya_list
  phase="$1"
  os_list=$(os_ids)
  ya_list=$(yashiki_ids)

  if [ -z "$os_list" ] || [ -z "$ya_list" ]; then
    log "$phase: ID 取得に失敗 (os=[$os_list] yashiki=[$ya_list]) -> 何もしない"
    return
  fi

  if [ "$os_list" = "$ya_list" ]; then
    log "$phase: 一致 [$os_list] -> set-outer-gap + retile"
    # shellcheck disable=SC2086
    "$YASHIKI" set-outer-gap $OUTER_GAP >/dev/null 2>&1 </dev/null || true
    "$YASHIKI" retile >/dev/null 2>&1 </dev/null || true
    [ "$phase" = "boot" ] || maybe_reload_sketchybar "$os_list"
    LAST_IDS="$os_list"
    return
  fi

  if [ "$phase" = "boot" ]; then
    log "boot: 不一致 yashiki=[$ya_list] os=[$os_list] -> retile のみ (boot では再起動しない)"
    "$YASHIKI" retile >/dev/null 2>&1 </dev/null || true
    LAST_IDS="$os_list"
    return
  fi

  if restart_allowed; then
    log "$phase: 不一致 yashiki=[$ya_list] os=[$os_list] -> yashiki 再起動"
    restart_yashiki
  else
    log "$phase: 不一致だが cooldown 中 yashiki=[$ya_list] os=[$os_list] -> retile のみ"
    "$YASHIKI" retile >/dev/null 2>&1 </dev/null || true
    maybe_reload_sketchybar "$os_list"
    LAST_IDS="$os_list"
  fi
}

sleep "$BOOT_DELAY"
settle boot </dev/null

# 購読を1回張って、切れるまで読み続ける。
#
# プロセス置換を exec で fd 3 に繋ぐ。bash 3.2 でも $! に置換先の子 PID が入るので
# （実測で kill -0 / kill が通ることを確認）、抜けるときに確実に始末できる。
# `done < <(...)` 形式だと子を掴めず、再購読のたびに subscribe がリークして
# 数十プロセス積み上がった。
# FIFO 経由も試したが、writer が生きているのに reader が即 EOF を受け取るため使えない。
subscribe_once() {
  local events pending quiet line rc spins window

  exec 3< <("$YASHIKI" subscribe --filter display 2>/dev/null </dev/null)
  SUB_PID=$!

  events=0
  pending=0
  quiet=0

  spins=0
  window=$(date +%s)

  while true; do
    IFS= read -r -t 1 line <&3
    rc=$?

    if [ "$rc" -eq 0 ]; then
      [ -z "$line" ] && continue
      case "$(printf '%s' "$line" | jq -r '.type' 2>/dev/null)" in
        display_added|display_removed|display_updated)
          events=$((events + 1))
          pending=1
          quiet=0
          ;;
      esac
      continue
    fi

    # ここに来たら read が非ゼロ。タイムアウトか EOF かを戻り値で区別してはいけない。
    # シェバンの /bin/bash は 3.2 で、read -t はタイムアウトでも 1 を返す
    # （128 超を返すのは bash 4.0 以降）。3.2 で >128 を条件にすると
    # 毎秒のタイムアウトを EOF と誤判定し、1 秒ごとに購読を張り直してしまう。
    # 子プロセスの生死で判定する。
    if ! kill -0 "$SUB_PID" 2>/dev/null; then
      break
    fi

    # 子は生きている = タイムアウト。
    # ただしパイプだけ閉じた場合に read が即座に返り続けて暴走しないよう、
    # 「1 秒に 1 回」から外れた頻度を検出したら張り直す。
    spins=$((spins + 1))
    if [ "$spins" -ge 10 ]; then
      if [ $(( $(date +%s) - window )) -lt 5 ]; then
        log "read が即座に返り続ける -> 購読を張り直す"
        break
      fi
      spins=0
      window=$(date +%s)
    fi

    if [ "$pending" -eq 1 ]; then
      quiet=$((quiet + 1))
      if [ "$quiet" -ge "$QUIET_TICKS" ]; then
        log "確定 (${events} イベント) -> 突き合わせ"
        settle event </dev/null
        # バースト単位のカウントにする（累積のままだと読みづらい）
        events=0
        pending=0
        quiet=0
      fi
    fi
  done

  exec 3<&-
  kill_subscription
  return 0
}

backoff=2
fail_streak=0
while true; do
  before=$(date +%s)
  subscribe_once
  elapsed=$(( $(date +%s) - before ))

  if [ "$elapsed" -ge 10 ]; then
    # ある程度続いた = 正常な購読だった。バックオフを戻す
    backoff=2
    if [ "$fail_streak" -gt 0 ]; then
      log "購読が回復した (${fail_streak} 回失敗のあと)"
      fail_streak=0
    fi
    log "購読が切断された -> 再購読"
  else
    # 即切れ。ログを溢れさせないよう間引きつつバックオフする
    fail_streak=$((fail_streak + 1))
    case "$fail_streak" in
      1|5|20|100) log "購読が即切断された (連続 ${fail_streak} 回) -> ${backoff}s 後に再試行" ;;
    esac
    backoff=$((backoff * 2))
    [ "$backoff" -gt "$BACKOFF_MAX" ] && backoff="$BACKOFF_MAX"
  fi

  sleep "$backoff"
done
