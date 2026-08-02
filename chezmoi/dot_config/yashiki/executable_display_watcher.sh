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
# ■ outer-gap をディスプレイごとに設定し直す
#   sketchybar の y_offset は全ディスプレイ共通だが、各ディスプレイが上部に確保
#   する量 (メニューバー / ノッチ帯) は異なる。yashiki はその可視領域から gap を
#   足すので、gap が共通だとバーとウィンドウの間隔がディスプレイごとにずれる。
#
#     ノッチ付き内蔵は自動非表示でもノッチ帯 38px を確保し続ける。
#     外部 (inset 0) と同じ gap 48 だと内蔵だけ 38px 余分に空く。
#
#   バーの直下 WINDOW_MARGIN に揃うよう、ディスプレイごとに gap.top を計算する:
#
#     gap.top = y_offset + bar_height + WINDOW_MARGIN - inset
#
#   y_offset と bar_height は sketchybar から読むので、bar.lua を変えても
#   ここを直す必要はない。init に固定値を書く方法はモニタの抜き差しに追従できず
#   (init は daemon 起動時に 1 回しか走らない)、メニューバー表示の切替でも
#   破綻するため採らない。
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
#   購読ペイロードの物理矩形 (physical_x/y/width/height) も fork 側の追加。
#   これが無いと inset を導けず、bar.lua に渡す値も出せない。
#
#   加えて上流はメニューバーの高さを CGWindowList の窓スキャンで測る。これは
#   「今描画されているか」であって「どれだけ予約しているか」ではないため、
#   ノッチ帯や全画面表示中に実際の予約量と食い違う。

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

# display_updated だけのバースト（メニューバー表示の切替、解像度変更など）は 1 tick 待つ。
#
# yashiki の状態自体は 1 件目の時点で確定している。だがイベントは変化した
# ディスプレイごとに 1 件ずつ飛び、こちらは list-outputs を引き直さず各イベントの
# ペイロードを DISPLAY_GEOM に積む方式なので、1 件目で settle すると 2 台目が
# 前回の値のまま残る。実測でメニューバー切替 1 回につき reload が 2 回走り、
# 1 回目は d2 が旧値 (inset=30) のまま gap とバー位置を決めていた。
#
# 同じ reconcile から出るイベントは連続して届くので、1 tick 無イベントを待てば
# 全台ぶんを取り込める。抜き差しほど構成が動き続けるわけではないので 1 で足りる。
#
# 抜き差しと混ざる場合の順序は問題にならない。reconcile_displays は added / removed を
# 先に発行してから updated を出すので、抜き差しなら必ず構造イベントを先に見る。
UPDATED_QUIET_TICKS=1

# sketchybar のバー下端とウィンドウ上端の間隔。左右/下の gap もこれに揃える
WINDOW_MARGIN=8
SIDE_GAP=12
# 購読が失敗し続けたときのバックオフ上限（秒）
BACKOFF_MAX=60

RUNDIR="${TMPDIR:-/tmp}"
LOG="$RUNDIR/yashiki_display_watcher.log"
LOCK="$RUNDIR/yashiki_display_watcher.pid"

# bar.lua に渡す主ディスプレイの inset。
#
# TMPDIR は使えない。ウォッチャーは yashiki の init から、sketchybar は brew
# services から起動されるので、片方に TMPDIR が無いと /tmp に落ちて相手を見失う。
# XDG_CACHE_HOME も launchd 配下には渡らないため、既定値を直に書く。
INSET_FILE="$HOME/.cache/yashiki/bar_inset"

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

# 現在のジオメトリ。購読で流れてくる状態をそのまま保持する。
#
# ID の集合ではなくジオメトリで比較すること。バーの y_offset はメニューバーが
# 確保している高さに依存するので、ディスプレイの増減がなくても表示設定が
# 変われば置き直しが要る。ID だけで見ていたときは「構成は不変」と判断して
# reload を飛ばし、メニューバーが消えてもバーが下がったままだった。
#
# subscribe は snapshot と各イベントでディスプレイの状態をそのまま載せてくるので、
# list-outputs で取り直さない。取り直すと同じ情報を二度問い合わせることになるし、
# イベント時点の状態とずれる余地も生まれる。
#
# gap の計算には各ディスプレイの上部予約量 (inset) が要る。可視領域だけでは
# 求まらないが、購読ストリームは物理矩形も載せてくるので
#   inset = 可視.y - 物理.y
# で出せる。NSScreen を別途叩く必要はない（叩くと値の由来が二重になるうえ、
# AppKit のスクリーンキャッシュを避けるため短命プロセスを起動する羽目になる）。
#
# is_main も持つ。bar.lua の y_offset は主ディスプレイの inset で決まるので、
# 主が移っただけでもバーを置き直す必要がある。
#
# 連想配列は使わない。シェバンの /bin/bash は 3.2 で declare -A がない。
# "id=x,y,w,h,inset,is_main" を改行区切りで持つ。
DISPLAY_GEOM=""

geom_put() {  # $1=id  $2=geom
  DISPLAY_GEOM=$(printf '%s' "$DISPLAY_GEOM" | grep -v "^$1=" ; printf '%s=%s\n' "$1" "$2")
}

geom_drop() {  # $1=id
  DISPLAY_GEOM=$(printf '%s' "$DISPLAY_GEOM" | grep -v "^$1=")
}

geom_signature() {
  printf '%s' "$DISPLAY_GEOM" | grep -v '^$' | LC_ALL=C sort | tr '\n' ';'
}

# snapshot 行から全ディスプレイを取り込む
absorb_snapshot() {
  local id geom
  DISPLAY_GEOM=""
  while IFS='|' read -r id geom; do
    case "$id" in ''|*[!0-9]*) continue ;; esac
    geom_put "$id" "$geom"
  done < <(printf '%s' "$1" | jq -r '.displays[]? | "\(.id)|\(.x),\(.y),\(.width),\(.height),\(.y - .physical_y),\(if .is_main then 1 else 0 end)"' 2>/dev/null)
}

# display_added / display_updated 行から 1 台ぶんを取り込む
absorb_display() {
  local pair id geom
  pair=$(printf '%s' "$1" | jq -r '.display | "\(.id)|\(.x),\(.y),\(.width),\(.height),\(.y - .physical_y),\(if .is_main then 1 else 0 end)"' 2>/dev/null)
  id=${pair%%|*}
  geom=${pair#*|}
  case "$id" in ''|*[!0-9]*) return 1 ;; esac
  geom_put "$id" "$geom"
}

forget_display() {
  local id
  id=$(printf '%s' "$1" | jq -r '.display_id // empty' 2>/dev/null)
  case "$id" in ''|*[!0-9]*) return 1 ;; esac
  geom_drop "$id"
}

LAST_GEOM=""

# ディスプレイごとに gap.top を計算して適用する。
# バーの位置と高さを読む。
#
# --reload 直後の sketchybar は設定を読み込み終えるまで既定値 (y_offset=0,
# height=25) を返す。値として妥当なので「数値かどうか」では弾けない。実際それで
# base を 0+25+8=33 と誤算し、gap が全ディスプレイでずれた。
# 同じ値が続けて取れるまで待って、設定適用後の値であることを確かめる。
sketchybar_bar_metrics() {
  local i out cur prev stable
  prev=""
  stable=0
  for i in $(seq 1 20); do
    out=$("$SKETCHYBAR" --query bar 2>/dev/null)
    cur=$(printf '%s' "$out" | jq -r '"\(.y_offset // "") \(.height // "")"' 2>/dev/null)
    case "$cur" in
      ''|*[!0-9\ ]*|' '*|*' ') cur="" ;;
    esac
    if [ -n "$cur" ] && [ "$cur" = "$prev" ]; then
      stable=$((stable + 1))
      if [ "$stable" -ge 2 ]; then
        printf '%s' "$cur"
        return 0
      fi
    else
      stable=0
    fi
    prev="$cur"
    sleep 0.2
  done
  return 1
}

# 主ディスプレイの inset を bar.lua へ渡す。
#
# bar.lua は y_offset にこれを足す。足さないとメニューバー固定表示のときバーが
# その裏に潜る。sketchybar の y_offset は全ディスプレイ共通なので主ディスプレイ
# 基準でよい (NSScreen.mainScreen を見ていた頃と同じ基準)。
#
# bar.lua 側で OS を見に行かせない。yashiki の購読ペイロードから導いた値と
# NSScreen から読んだ値の二系統になると、食い違ったときに原因を追えなくなる。
publish_main_inset() {
  local inset
  # "id=x,y,w,h,inset,is_main" を = と , で割る -> $6=inset, $7=is_main
  inset=$(printf '%s' "$DISPLAY_GEOM" | grep -v '^$' \
    | awk -F'[=,]' '$7 == 1 { print $6; exit }')
  case "$inset" in ''|*[!0-9]*) return 0 ;; esac
  mkdir -p "${INSET_FILE%/*}" 2>/dev/null || return 0
  printf '%s\n' "$inset" >"$INSET_FILE" 2>/dev/null || true
}

apply_outer_gaps() {
  local metrics yoff height base id inset top
  [ -x "$SKETCHYBAR" ] || return 0
  metrics=$(sketchybar_bar_metrics) || {
    log "  sketchybar の値を取得できず gap 計算を見送り"
    return 0
  }
  yoff=${metrics% *}
  height=${metrics#* }

  base=$((yoff + height + WINDOW_MARGIN))
  printf '%s' "$DISPLAY_GEOM" | grep -v '^$' | while IFS='=' read -r id geom; do
    [ -n "$id" ] || continue
    inset=${geom%,*}
    inset=${inset##*,}
    case "$inset" in ''|*[!0-9]*) inset=0 ;; esac
    top=$((base - inset))
    [ "$top" -lt 0 ] && top=0
    log "  display $id: inset=$inset -> gap.top=$top"
    "$YASHIKI" set-outer-gap --output "$id" "$top" "$SIDE_GAP" "$SIDE_GAP" "$SIDE_GAP" \
      >/dev/null 2>&1 </dev/null || log "  display $id への set-outer-gap に失敗"
  done
}

# ジオメトリが変わったら gap を計算し直し、sketchybar を作り直す。
# --reload はバーが一瞬消えるので、変わっていない回まで巻き込まない。
settle() {
  local geom
  geom=$(geom_signature)
  [ -n "$geom" ] || return 0
  if [ "$geom" = "$LAST_GEOM" ]; then
    log "ジオメトリ不変 -> 何もしない"
    return 0
  fi
  LAST_GEOM="$geom"
  log "ジオメトリ変化 -> sketchybar --reload + gap 再計算"
  # inset の受け渡しを先に。bar.lua は reload の中で読むので、書くのが後だと
  # 一世代古い値でバーが置かれる。
  publish_main_inset
  # 次に reload。gap は reload 後の y_offset から決まるので順序を逆にできない。
  [ -x "$SKETCHYBAR" ] && "$SKETCHYBAR" --reload >/dev/null 2>&1 </dev/null
  apply_outer_gaps
  return 0
}

# 購読を1回張って、切れるまで読み続ける。
#
# プロセス置換を exec で fd 3 に繋ぐ。bash 3.2 でも $! に置換先の子 PID が入るので
# 抜けるときに確実に始末できる。`done < <(...)` 形式だと子を掴めず、再購読のたびに
# subscribe がリークして数十プロセス積み上がった。FIFO 経由も試したが、writer が
# 生きているのに reader が即 EOF を受け取るため使えない。
subscribe_once() {
  local events pending quiet line rc spins window structural need why

  # --snapshot を付けると接続直後に全ディスプレイの状態が届く。これを基準にする
  # ので、起動時に list-outputs を叩く必要も、構成が落ち着くのを待つ必要もない。
  exec 3< <("$YASHIKI" subscribe --snapshot --filter display 2>/dev/null </dev/null)
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
        snapshot)
          # 購読開始時の全状態。
          #
          # ここで settle まで走らせる。init は sketchybar を exec --track で
          # 起動するだけで --reload しないので、これを省くと inset を書く前に
          # 上がった sketchybar が前回値のままになる。
          #
          # sketchybar がまだ上がっていなくても apply_outer_gaps 側の
          # sketchybar_bar_metrics が最大 4 秒粘るので、init が起動するのを待てる。
          absorb_snapshot "$line"
          log "snapshot を取り込み -> 初期化"
          LAST_GEOM=""
          settle </dev/null
          ;;
        display_added)
          absorb_display "$line"
          events=$((events + 1))
          structural=1
          pending=1
          quiet=0
          ;;
        display_removed)
          forget_display "$line"
          events=$((events + 1))
          structural=1
          pending=1
          quiet=0
          ;;
        display_updated)
          absorb_display "$line"
          events=$((events + 1))
          pending=1
          quiet=0
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
      if [ "$structural" -eq 1 ]; then
        need="$QUIET_TICKS"
        why="抜き差し"
      else
        need="$UPDATED_QUIET_TICKS"
        why="更新のみ"
      fi
      if [ "$quiet" -ge "$need" ]; then
        log "確定 (${events} イベント, ${why})"
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
