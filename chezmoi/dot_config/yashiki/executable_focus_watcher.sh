#!/bin/bash
# Long-running watcher that reacts to yashiki's focus state.
#
#   1. Switch the JankyBorders frame colour between floating and tiling
#   2. Restore focus when it ends up nowhere
#
# yashiki has no event hooks (exec runs immediately), so subscribe is the only
# way to observe state. Started in the background from init, which puts it in
# yashiki's process group.
#
# Keep this out of yashiki_bridge.sh: none of it concerns sketchybar.

set -u

# Use the same binary as the running daemon. Subcommands are parsed by the CLI
# before they reach IPC, so a version mismatch gets rejected.
# Only treat it as the daemon when invoked with no arguments or with start,
# otherwise CLI invocations match too.
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

# Carried over from the previous AeroSpace setup: floating orange, tiling white
BORDER_FLOATING=0xfff5a97f
BORDER_TILING=0xffe1e3e4
BORDER_INACTIVE=0xff494d64

RUNDIR="${TMPDIR:-/tmp}"
LOCK="$RUNDIR/yashiki_focus_watcher.pid"
BACKOFF_MAX=60

# Guard against a second instance. pgrep fails silently when directory services
# are wedged, so use a pid file that kill -0 can verify.
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

# Is a menu open? Layer 101 is kCGPopUpMenuWindowLevel, where both menu bar
# menus and context menus live. Same signal yashiki itself uses to suppress
# auto-raise.
#
# ObjC.deepUnwrap cannot unwrap what CGWindowListCopyWindowInfo returns, so call
# it through bindFunction. Costs 64ms, but only runs when focus is lost.
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

# Restore focus when it ends up nowhere, otherwise alt-hjkl stops working.
#
# Leave it alone while a menu is open. Moving focus deactivates the app showing
# the menu, which dismisses it. Menu bar apps that own no window report focus as
# lost the moment their menu opens.
recover_focus() {
  popup_menu_open && return 0
  "$YASHIKI" window-focus next >/dev/null 2>&1 </dev/null &
}

# window_focused carries only a window_id, so keep the set of floating window
# ids here rather than running list-windows on every focus change.
# The shebang's bash is 3.2, which has no declare -A, hence a space-separated
# string.
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
