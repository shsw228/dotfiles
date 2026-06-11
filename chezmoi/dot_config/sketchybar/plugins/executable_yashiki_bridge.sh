#!/bin/bash
# yashiki の state stream を購読し、sketchybar 側へ
#   yashiki_workspace_change (ACTIVE_TAGS / OCCUPIED_TAGS)
#   yashiki_focus_change     (FLOAT=true|false)
# のカスタムイベントを発火するブリッジ。
# sketchybarrc から & 起動する常駐プロセス。

set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "yashiki_bridge: jq is required" >&2
  exit 1
fi

if ! command -v yashiki >/dev/null 2>&1; then
  echo "yashiki_bridge: yashiki not found in PATH" >&2
  exit 1
fi

SKETCHYBAR="/opt/homebrew/bin/sketchybar"

# 状態:
#   displays[id]=visible_tags
#   windows[id]={tags,floating}
#   focused=focused_display_id (string)
#   focused_window=focused_window_id (string)
STATE='{"displays":{},"windows":{},"focused":"0","focused_window":"0"}'

trigger_workspace() {
  local active occupied=0 t
  active=$(echo "$STATE" | jq -r '.displays[.focused] // 0')
  for t in $(echo "$STATE" | jq -r '.windows[].tags // 0'); do
    occupied=$((occupied | t))
  done
  "$SKETCHYBAR" --trigger yashiki_workspace_change \
    ACTIVE_TAGS="$active" \
    OCCUPIED_TAGS="$occupied" 2>/dev/null
}

trigger_focus() {
  local floating
  floating=$(echo "$STATE" | jq -r '.windows[.focused_window].floating // false')
  "$SKETCHYBAR" --trigger yashiki_focus_change FLOAT="$floating" 2>/dev/null
}

process_snapshot() {
  STATE=$(echo "$1" | jq '{
    displays: (.displays | map({(.id | tostring): .visible_tags}) | add // {}),
    windows: (.windows | map({(.id | tostring): {tags: .tags, floating: .is_floating}}) | add // {}),
    focused: (.focused_display_id | tostring),
    focused_window: (.focused_window_id // 0 | tostring)
  }')
  trigger_workspace
  trigger_focus
}

process_event() {
  local line="$1" type
  type=$(echo "$line" | jq -r '.type')
  case "$type" in
    tags_changed)
      local did vtags
      did=$(echo "$line" | jq -r '.display_id')
      vtags=$(echo "$line" | jq -r '.visible_tags')
      STATE=$(echo "$STATE" | jq --arg did "$did" --argjson vtags "$vtags" '.displays[$did] = $vtags')
      trigger_workspace
      ;;
    display_focused)
      local did
      did=$(echo "$line" | jq -r '.display_id')
      STATE=$(echo "$STATE" | jq --arg did "$did" '.focused = $did')
      trigger_workspace
      trigger_focus
      ;;
    window_created|window_updated)
      local wid wtags wfloat wfocused
      wid=$(echo "$line" | jq -r '.window.id')
      wtags=$(echo "$line" | jq -r '.window.tags')
      wfloat=$(echo "$line" | jq -r '.window.is_floating')
      wfocused=$(echo "$line" | jq -r '.window.is_focused')
      STATE=$(echo "$STATE" | jq --arg wid "$wid" --argjson wtags "$wtags" --argjson wfloat "$wfloat" \
        '.windows[$wid] = {tags: $wtags, floating: $wfloat}')
      if [ "$wfocused" = "true" ]; then
        STATE=$(echo "$STATE" | jq --arg wid "$wid" '.focused_window = $wid')
      fi
      trigger_workspace
      trigger_focus
      ;;
    window_destroyed)
      local wid
      wid=$(echo "$line" | jq -r '.window_id')
      STATE=$(echo "$STATE" | jq --arg wid "$wid" 'del(.windows[$wid])')
      trigger_workspace
      trigger_focus
      ;;
  esac
}

while true; do
  yashiki subscribe --snapshot --filter tags,focus,window 2>/dev/null | while IFS= read -r line; do
    [ -z "$line" ] && continue
    type=$(echo "$line" | jq -r '.type')
    if [ "$type" = "snapshot" ]; then
      process_snapshot "$line"
    else
      process_event "$line"
    fi
  done
  sleep 2
done
