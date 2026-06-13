#!/bin/sh
# tatami の main-count を増減しつつ、自前カウンタ ~/.cache/yashiki/main_count を
# 更新し、sketchybar 側へ通知 (yashiki_main_count_change イベント発火) する。
#
# 使い方:
#   main_count.sh inc       # +1
#   main_count.sh dec       # -1 (最低1)
#   main_count.sh read      # 現在値出力
#   main_count.sh notify    # 現在値を sketchybar へ送るだけ
#
# tatami は getter API が無いため値の信頼性は本スクリプト経由の操作に限る。

set -eu

YASHIKI="/opt/homebrew/bin/yashiki"
SKETCHYBAR="/opt/homebrew/bin/sketchybar"
COUNTER="${HOME}/.cache/yashiki/main_count"

mkdir -p "$(dirname "$COUNTER")"
[ -f "$COUNTER" ] || echo 1 > "$COUNTER"

case "${1:-}" in
  inc)
    v=$(cat "$COUNTER")
    v=$((v + 1))
    echo "$v" > "$COUNTER"
    "$YASHIKI" layout-cmd inc-main-count >/dev/null 2>&1 || true
    ;;
  dec)
    v=$(cat "$COUNTER")
    v=$((v - 1))
    [ "$v" -lt 1 ] && v=1
    echo "$v" > "$COUNTER"
    "$YASHIKI" layout-cmd dec-main-count >/dev/null 2>&1 || true
    ;;
  read)
    cat "$COUNTER"
    exit 0
    ;;
  notify) ;;
  *)
    echo "usage: $(basename "$0") {inc|dec|read|notify}" >&2
    exit 64
    ;;
esac

"$SKETCHYBAR" --trigger yashiki_main_count_change COUNT="$(cat "$COUNTER")" 2>/dev/null || true
