#!/bin/bash
# ディスプレイ構成変更を検知して sketchybar を再起動する watcher。
# sketchybar の item 構成 (notch_spacer, audio_simple 等) は起動時の display
# 構成に依存するため、抜き差し後は item を作り直さないと整合が取れない。
#
# 仕組み: yashiki subscribe --filter display で display_added/removed/updated
# イベントを購読。発火したら sketchybar を pkill する → launchd KeepAlive が
# 自動で再起動 → 新構成で init.lua が走り items 再生成。
#
# sketchybarrc (init.lua の sbar.exec) から & で起動して常駐させる。

set -u

YASHIKI="/opt/homebrew/bin/yashiki"
SELF_PID=$$

# 多重起動防止: 自分以外の display_watcher.sh を kill
for pid in $(pgrep -f '^(/[^ ]*/)?bash .*/display_watcher\.sh$'); do
  [ "$pid" = "$SELF_PID" ] && continue
  kill "$pid" 2>/dev/null
done

while true; do
  "$YASHIKI" subscribe --filter display 2>/dev/null | while IFS= read -r line; do
    [ -z "$line" ] && continue
    type=$(echo "$line" | jq -r '.type' 2>/dev/null)
    case "$type" in
      display_added|display_removed|display_updated)
        pkill -9 sketchybar 2>/dev/null
        exit 0
        ;;
    esac
  done
  # subscribe が切断された場合は短時間待ってリトライ
  sleep 2
done
