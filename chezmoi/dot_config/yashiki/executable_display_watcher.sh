#!/bin/bash
# ディスプレイ構成が変わったら sketchybar を作り直す常駐ウォッチャー。
#
# ■ なぜ必要か
#   sketchybar 本体もディスプレイの抜き差しを検知する (src/display.c) が、やるのは
#   バーウィンドウの再配置までで item 構成は作り直さない。notch_spacer や
#   bar.lua の y_offset は起動時の構成から決めているので、構成が変わったら
#   --reload しないと合わなくなる。--reload は bar_manager_destroy + init +
#   exec_config_file なので item ごと組み直せる。
#
#   sketchybar 自身の display_change イベントは使えない。あれはアクティブな
#   ディスプレイが変わったときにも飛ぶので、フォーカス移動のたびにバーが
#   作り直されてしまう。yashiki の display イベントを購読するのはそのため。
#
# ■ やらないこと
#   yashiki のタイル配置には触らない。ディスプレイ再構成でもメニューバー表示の
#   変更でも yashiki 自身が読み直して retile するので、こちらから retile や
#   set-outer-gap を打つ必要はない。
#
# ■ yashiki のビルド依存
#   使っているコマンド (subscribe / list-outputs) は上流 0.15.2 にもあるので、
#   ディスプレイの抜き差しは上流ビルドでも追従する。
#
#   ただしメニューバー表示の切替は fork ビルド (shsw228/yashiki の
#   fix/display-reconfiguration) が要る。上流は NSApplicationDidChangeScreenParameters
#   を「display callback が拾うから」と握り潰しており、メニューバーの表示切替は
#   ディスプレイ再構成を伴わないため display イベントが 1 件も飛ばない。
#   その状態ではこのウォッチャーは起動せず、バーは下がったままになる。
#
#   加えて上流はメニューバーの高さを CGWindowList の窓スキャンで測るため、
#   bar.lua が使う visibleFrame と値が食い違うことがある。

set -u

# CLI は稼働中の daemon と同じバイナリを使う。
#
# サブコマンドは CLI 側でパースされてから IPC に載るため、CLI と daemon の版が
# 食い違うと弾かれる。別ビルドの daemon を動かしているときに PATH の Homebrew 版
# CLI を叩いてしまう事故が実際に起きた。
#
# app バンドルから open で起動された daemon は引数を持たず、launchd 経由や
# 手動起動では "start" が付く。CLI 呼び出しを拾わないよう、引数なしか start の
# ときだけ daemon とみなす。
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
SKETCHYBAR="/opt/homebrew/bin/sketchybar"

# display_added / display_removed（抜き差し）を含むバーストは、構成が確定するまで
# ジオメトリが数秒動き続ける。途中で確定すると中間状態で sketchybar を組み直して
# しまうので、1 秒 tick で QUIET_TICKS 回続けて無イベントになるまで待つ。
QUIET_TICKS=3

# display_updated だけのバースト（メニューバー表示の切替、解像度変更など）は待たない。
#
# yashiki は全ディスプレイを再取得し終えてからイベントを発行する。実測でも 1 件目を
# 受け取った時点で list-outputs は既に最終ジオメトリを返しており、2 件目でも最終値でも
# 内容は同じだった。つまり待っても新しい情報は増えない。
#
# ディスプレイの数だけイベントが飛ぶが、2 件目以降は settle のジオメトリ比較が
# 弾くので reload は 1 回で済む。
#
# 抜き差しと混ざる場合の順序は問題にならない。reconcile_displays は added / removed を
# 先に発行してから updated を出すので、抜き差しなら必ず構造イベントを先に見る。
# ログイン直後は構成が動いている最中なので、基準を取るまでこれだけ待つ
BOOT_DELAY=5
# 購読が失敗し続けたときのバックオフ上限（秒）
BACKOFF_MAX=60

RUNDIR="${TMPDIR:-/tmp}"
LOG="$RUNDIR/yashiki_display_watcher.log"
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

# ログは追記しつつ肥大化を防ぐ
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

log "start pid=$$ (yashiki=$YASHIKI)"

# yashiki が認識しているジオメトリ全体。
#
# ID の集合ではなくジオメトリで比較すること。バーの y_offset はメニューバーが
# 確保している高さに依存するので、ディスプレイの増減がなくても表示設定が
# 変われば置き直しが要る。ID だけで見ていたときは「構成は不変」と判断して
# reload を飛ばし、メニューバーが消えてもバーが下がったままだった。
yashiki_geometry() {
  "$YASHIKI" list-outputs 2>/dev/null \
    | awk '/^[0-9]+:/ { print }' | LC_ALL=C sort | tr '\n' ';'
}

LAST_GEOM=""

# ジオメトリが変わっていたら sketchybar を作り直す。
# --reload はバーが一瞬消えるので、変わっていない回まで巻き込まない。
settle() {
  local geom
  geom=$(yashiki_geometry)
  [ -n "$geom" ] || return 0
  if [ "$geom" = "$LAST_GEOM" ]; then
    log "ジオメトリ不変 -> reload しない"
    return 0
  fi
  LAST_GEOM="$geom"
  log "ジオメトリ変化 -> sketchybar --reload"
  [ -x "$SKETCHYBAR" ] && "$SKETCHYBAR" --reload >/dev/null 2>&1 </dev/null
  return 0
}

sleep "$BOOT_DELAY"
# 起動時は比較の基準を取るだけ。init が直後に --reload するので触らない。
LAST_GEOM=$(yashiki_geometry)
log "基準ジオメトリを取得"

# 購読を1回張って、切れるまで読み続ける。
#
# プロセス置換を exec で fd 3 に繋ぐ。bash 3.2 でも $! に置換先の子 PID が入るので
# 抜けるときに確実に始末できる。`done < <(...)` 形式だと子を掴めず、再購読のたびに
# subscribe がリークして数十プロセス積み上がった。FIFO 経由も試したが、writer が
# 生きているのに reader が即 EOF を受け取るため使えない。
subscribe_once() {
  local events pending quiet line rc spins window structural

  exec 3< <("$YASHIKI" subscribe --filter display 2>/dev/null </dev/null)
  SUB_PID=$!

  events=0
  pending=0
  quiet=0
  structural=0
  spins=0
  window=$(date +%s)

  while true; do
    IFS= read -r -t 1 line <&3
    rc=$?

    if [ "$rc" -eq 0 ]; then
      [ -z "$line" ] && continue
      case "$(printf '%s' "$line" | jq -r '.type' 2>/dev/null)" in
        display_added|display_removed)
          events=$((events + 1))
          structural=1
          pending=1
          quiet=0
          ;;
        display_updated)
          events=$((events + 1))
          if [ "$structural" -eq 1 ]; then
            # 抜き差しの途中。確定を待つ
            pending=1
            quiet=0
          else
            log "確定 (display_updated, 待たない)"
            settle </dev/null
            events=0
            pending=0
            quiet=0
          fi
          ;;
      esac
      continue
    fi

    # ここに来たら read が非ゼロ。タイムアウトか EOF かを戻り値で区別してはいけない。
    # シェバンの /bin/bash は 3.2 で、read -t はタイムアウトでも 1 を返す
    # （128 超を返すのは bash 4.0 以降）。3.2 で >128 を条件にすると毎秒の
    # タイムアウトを EOF と誤判定し、1 秒ごとに購読を張り直してしまう。
    # 子プロセスの生死で判定する。
    if ! kill -0 "$SUB_PID" 2>/dev/null; then
      break
    fi

    # 子は生きている = タイムアウト。ただしパイプだけ閉じた場合に read が
    # 即座に返り続けて暴走しないよう、頻度が「1 秒に 1 回」から外れたら張り直す。
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
        log "確定 (${events} イベント, 抜き差し)"
        settle </dev/null
        events=0
        pending=0
        quiet=0
        structural=0
      fi
    fi
  done

  exec 3<&-
  kill_subscription
  return 0
}

daemon_alive() {
  "$YASHIKI" list-outputs >/dev/null 2>&1 </dev/null
}

back_off() {  # $1: ログに出す理由
  fail_streak=$((fail_streak + 1))
  case "$fail_streak" in
    1|5|20|100) log "$1 (連続 ${fail_streak} 回) -> ${backoff}s 後に再試行" ;;
  esac
  sleep "$backoff"
  backoff=$((backoff * 2))
  [ "$backoff" -gt "$BACKOFF_MAX" ] && backoff="$BACKOFF_MAX"
}

backoff=2
fail_streak=0
while true; do
  # daemon が入れ替わっているかもしれないので毎回解決し直す
  YASHIKI=$(resolve_yashiki)

  # daemon の生死を先に確かめる。
  # 以前は「購読が 10 秒以上続いたら正常」でバックオフを戻していたが、daemon が
  # 落ちていると subscribe の失敗自体に 10 秒前後かかるため判定が成立してしまい、
  # 実質バックオフが効かず 10 秒間隔で subscribe を撒き続けていた。
  if ! daemon_alive; then
    back_off "daemon に接続できない"
    continue
  fi

  before=$(date +%s)
  subscribe_once
  elapsed=$(( $(date +%s) - before ))

  if [ "$fail_streak" -gt 0 ]; then
    log "購読が回復した (${fail_streak} 回失敗のあと)"
  fi
  backoff=2
  fail_streak=0

  if [ "$elapsed" -ge 10 ]; then
    log "購読が切断された -> 再購読"
    sleep 2
  else
    back_off "購読が即切断された"
  fi
done
