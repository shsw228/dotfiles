#!/bin/bash
# yashiki の state stream を購読し、sketchybar 側へ
#   yashiki_workspace_change OUTPUT_{id}_ACTIVE_TAGS / _OCCUPIED_TAGS / _TAG_APPS_{1..10}
#   yashiki_focus_change     FLOAT=true|false
# を発火するブリッジ。各ディスプレイの状態を独立に送る。
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

# sketchybar 再起動で旧 bridge が残るのを防ぐため、自分以外の bridge を kill。
# pgrep -f は ps -ax の COMMAND を正規表現でマッチするので、引数経由で "yashiki_bridge.sh"
# を含むだけのプロセス (chezmoi apply 等) を巻き込まないよう、bash 実行パスを起点に絞り込む。
SELF_PID=$$
for pid in $(pgrep -f '^(/[^ ]*/)?bash .*/yashiki_bridge\.sh$'); do
  [ "$pid" = "$SELF_PID" ] && continue
  kill "$pid" 2>/dev/null
done

SKETCHYBAR="/opt/homebrew/bin/sketchybar"
BORDERS="/opt/homebrew/bin/borders"
YASHIKI="/opt/homebrew/bin/yashiki"

# borders は yashiki から exec --track 起動。focus変更時に色を切替えるため
# 旧 aerospace 設定にあった floating=オレンジ / tiling=白 のロジックを復元。
update_borders() {
  local floating="$1"
  if [ "$floating" = "true" ]; then
    "$BORDERS" active_color=0xfff5a97f inactive_color=0xff494d64 width=5.0 2>/dev/null &
  else
    "$BORDERS" active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0 2>/dev/null &
  fi
}

# 状態:
#   displays[id]=visible_tags
#   windows[id]={tags, floating, app_id, output}
#   focused=focused_display_id (string)
#   focused_window=focused_window_id (string)
STATE='{"displays":{},"windows":{},"focused":"0","focused_window":"0"}'

trigger_workspace() {
  local args
  args=$(echo "$STATE" | python3 -c '
import json, sys
state = json.load(sys.stdin)
displays = state.get("displays", {})
windows  = state.get("windows", {})

lines = []
for disp_id, vtags in displays.items():
    # active = そのディスプレイの visible_tags
    lines.append(f"OUTPUT_{disp_id}_ACTIVE_TAGS={vtags}")

    # occupied = そのディスプレイに存在する window の tags の和
    occupied = 0
    tag_apps = [[] for _ in range(10)]
    for win in windows.values():
        if str(win.get("output", "")) != str(disp_id):
            continue
        tags = int(win.get("tags") or 0)
        app  = win.get("app_id") or ""
        occupied |= tags
        if app:
            for i in range(10):
                if tags & (1 << i):
                    if app not in tag_apps[i]:
                        tag_apps[i].append(app)

    lines.append(f"OUTPUT_{disp_id}_OCCUPIED_TAGS={occupied}")
    for i, apps in enumerate(tag_apps):
        lines.append(f"OUTPUT_{disp_id}_TAG_APPS_{i+1}=" + ",".join(apps))

print("\n".join(lines))
')

  local sb_args=()
  while IFS= read -r kv; do
    [ -z "$kv" ] && continue
    sb_args+=("$kv")
  done <<< "$args"

  "$SKETCHYBAR" --trigger yashiki_workspace_change "${sb_args[@]}" 2>/dev/null
}

trigger_focus() {
  local floating
  floating=$(echo "$STATE" | jq -r '.windows[.focused_window].floating // false')
  "$SKETCHYBAR" --trigger yashiki_focus_change FLOAT="$floating" 2>/dev/null
  update_borders "$floating"
}

process_snapshot() {
  STATE=$(echo "$1" | jq '{
    displays: (.displays | map({(.id | tostring): .visible_tags}) | add // {}),
    windows:  (.windows  | map({(.id | tostring): {tags: .tags, floating: .is_floating, app_id: (.app_id // ""), output: .output_id}}) | add // {}),
    focused:  (.focused_display_id | tostring),
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
    window_focused)
      local wid
      wid=$(echo "$line" | jq -r '.window_id // "null"')
      if [ "$wid" = "null" ] || [ "$wid" = "0" ] || [ -z "$wid" ]; then
        # focus が失効した (主に新規 window 作成直後)。alt-hjkl 等が効かなくなる
        # ため window-focus next で focus を回復する
        "$YASHIKI" window-focus next 2>/dev/null &
      else
        STATE=$(echo "$STATE" | jq --arg wid "$wid" '.focused_window = $wid')
        trigger_focus
      fi
      ;;
    window_created|window_updated)
      local wid wtags wfloat wfocused wapp woutput
      wid=$(echo "$line" | jq -r '.window.id')
      wtags=$(echo "$line" | jq -r '.window.tags')
      wfloat=$(echo "$line" | jq -r '.window.is_floating')
      wfocused=$(echo "$line" | jq -r '.window.is_focused')
      wapp=$(echo "$line" | jq -r '.window.app_id // ""')
      woutput=$(echo "$line" | jq -r '.window.output_id')
      STATE=$(echo "$STATE" | jq --arg wid "$wid" --argjson wtags "$wtags" --argjson wfloat "$wfloat" --arg wapp "$wapp" --argjson woutput "$woutput" \
        '.windows[$wid] = {tags: $wtags, floating: $wfloat, app_id: $wapp, output: $woutput}')
      if [ "$wfocused" = "true" ]; then
        STATE=$(echo "$STATE" | jq --arg wid "$wid" '.focused_window = $wid')
      fi
      trigger_workspace
      trigger_focus
      ;;
    mode_changed)
      local mode
      mode=$(echo "$line" | jq -r '.mode // "normal"')
      "$SKETCHYBAR" --trigger yashiki_mode_change MODE="$mode" 2>/dev/null
      ;;
    window_destroyed)
      local wid focused
      wid=$(echo "$line" | jq -r '.window_id')
      STATE=$(echo "$STATE" | jq --arg wid "$wid" 'del(.windows[$wid])')
      # destroyed なのが focused window だったら yashiki に focus 回復させる
      focused=$("$YASHIKI" focused-window 2>/dev/null)
      if [ -z "$focused" ] || [ "$focused" = "$wid" ]; then
        "$YASHIKI" window-focus next 2>/dev/null &
      fi
      trigger_workspace
      trigger_focus
      ;;
  esac
}

while true; do
  yashiki subscribe --snapshot --filter tags,focus,window,mode 2>/dev/null | while IFS= read -r line; do
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
