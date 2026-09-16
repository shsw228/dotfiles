#!/bin/sh
# AeroSpace の状態を sketchybar へ流す。
#
# yashiki には state stream があり、Rust の bridge が購読して押し込んでいた。
# AeroSpace にストリームは無く、設定から呼ばれるコールバックしか無いので、
# 呼ばれるたびに問い合わせて --trigger で渡す。
#
# 渡す形は yashiki 時代と揃えてある (items/aerospace.lua が読む):
#   OUTPUT_<mon>_ACTIVE     可視ワークスペース名
#   OUTPUT_<mon>_OCCUPIED   窓のあるワークスペース名の CSV
#
# 引数: workspace | focus  (どちらのイベントとして投げるか)
set -eu

AEROSPACE=/opt/homebrew/bin/aerospace
SKETCHYBAR=/opt/homebrew/bin/sketchybar

[ -x "$AEROSPACE" ] || exit 0
[ -x "$SKETCHYBAR" ] || exit 0

event="aerospace_workspace_change"
[ "${1:-workspace}" = "focus" ] && event="aerospace_focus_change"

# モニタ番号の一覧。list-monitors は "1 | Built-in Retina Display" 形式。
monitors=$("$AEROSPACE" list-monitors --format '%{monitor-id}' 2>/dev/null) || exit 0
[ -n "$monitors" ] || exit 0

args=""
for mon in $monitors; do
  visible=$("$AEROSPACE" list-workspaces --monitor "$mon" --visible 2>/dev/null | head -1)
  occupied=$("$AEROSPACE" list-workspaces --monitor "$mon" --empty no 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  args="$args OUTPUT_${mon}_ACTIVE=${visible:-} OUTPUT_${mon}_OCCUPIED=${occupied:-}"
done

# shellcheck disable=SC2086
"$SKETCHYBAR" --trigger "$event" $args >/dev/null 2>&1 || true
