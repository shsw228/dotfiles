#!/bin/bash
# Long-running watcher that rebuilds sketchybar when the display configuration
# changes, and re-applies the per-display outer gap.
#
# ■ Why it is needed
#   sketchybar detects hotplugs itself (src/display.c), but only repositions the
#   bar window; it does not rebuild the items. notch_spacer and bar.lua's
#   y_offset are derived from the configuration at startup, so a change needs a
#   --reload, which is bar_manager_destroy + init + exec_config_file and does
#   rebuild them.
#
#   sketchybar's own display_change event is unusable: it also fires when the
#   active display changes, which would rebuild the bar on every focus move.
#   Hence subscribing to yashiki's display events instead.
#
# ■ Per-display outer gap
#   sketchybar's y_offset is shared by all displays, but each one reserves a
#   different amount at the top (menu bar, notch). yashiki adds the gap to the
#   usable area, so one shared gap leaves the bar and the windows at different
#   distances on different displays.
#
#     A notched built-in panel keeps its 38px strip even with the menu bar
#     auto-hidden. With the same gap of 48 as an external display (inset 0) the
#     built-in one ends up 38px lower.
#
#   Compute gap.top per display so the windows sit WINDOW_MARGIN below the bar:
#
#     gap.top = y_offset + bar_height + WINDOW_MARGIN - inset
#
#   y_offset and bar_height are read from sketchybar, so changing bar.lua does
#   not require touching this. A fixed value in init is not an option: init runs
#   once at daemon startup, so it cannot follow hotplugs or menu bar changes.
#
# ■ yashiki build requirements
#   subscribe and list-outputs exist in upstream 0.15.2, so hotplugs are
#   followed on an upstream build as well.
#
#   Menu bar visibility changes need the fork (shsw228/yashiki,
#   fix/display-reconfiguration). Upstream ignores
#   NSApplicationDidChangeScreenParameters on the grounds that the display
#   callback covers it, but toggling the menu bar involves no display
#   reconfiguration, so not a single display event is emitted and this watcher
#   never wakes up.
#
#   The physical rectangle in the subscription payload (physical_x/y/width/
#   height) is also a fork addition. Without it the inset cannot be derived, and
#   neither can the value handed to bar.lua.
#
#   Upstream also measures the menu bar height by scanning the window list,
#   which reports what is drawn rather than what is reserved, and therefore
#   disagrees with the real reservation around notches and fullscreen spaces.

set -u

# Use the same binary as the running daemon.
#
# Subcommands are parsed by the CLI before they reach IPC, so a version mismatch
# gets rejected. Reaching for the Homebrew CLI on PATH while a different build
# runs as the daemon is easy to do by accident.
#
# A daemon launched from the app bundle with open carries no arguments; via
# launchd or by hand it carries "start". Match only those two so CLI
# invocations are not mistaken for the daemon.
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

# A burst containing display_added or display_removed keeps moving for a few
# seconds until the configuration settles. Acting early would rebuild sketchybar
# against an intermediate state, so wait for QUIET_TICKS consecutive idle ticks
# of one second each.
QUIET_TICKS=3

# A burst of display_updated alone (menu bar toggle, resolution change) waits
# one tick.
#
# yashiki's own state is final by the time the first event arrives, but events
# come one per changed display, and this script accumulates their payloads into
# DISPLAY_GEOM rather than re-reading list-outputs. Settling on the first event
# would leave the second display at its previous value.
#
# Events from one reconcile arrive back to back, so a single idle tick is enough
# to take them all in. The configuration is not still moving the way it is
# during a hotplug.
#
# Mixing with a hotplug is safe: reconcile_displays emits added and removed
# before updated, so a structural event is always seen first.
UPDATED_QUIET_TICKS=1

# Distance between the bottom of the bar and the top of a window. The side and
# bottom gaps match it.
WINDOW_MARGIN=8
SIDE_GAP=12
# Upper bound in seconds for the reconnect backoff
BACKOFF_MAX=60

RUNDIR="${TMPDIR:-/tmp}"
LOG="$RUNDIR/yashiki_display_watcher.log"
LOCK="$RUNDIR/yashiki_display_watcher.pid"

# The main display's inset, handed to bar.lua.
#
# TMPDIR is no good here: the two sides are started from different places, and
# if either lacks TMPDIR it falls back to /tmp and they lose each other.
# XDG_CACHE_HOME does not reach processes under launchd either, so spell out the
# default path.
INSET_FILE="$HOME/.cache/yashiki/bar_inset"

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" >>"$LOG" 2>/dev/null || true; }

# Guard against a second instance. pgrep fails silently with "Cannot get process
# list" when directory services are wedged, so use a pid file that kill -0 can
# verify.
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

# Append, but do not let the log grow without bound
if [ -f "$LOG" ] && [ "$(wc -l <"$LOG" 2>/dev/null || echo 0)" -gt 500 ]; then
  : >"$LOG" 2>/dev/null || true
fi

SUB_PID=""

# Tear the subscription down completely.
# Process substitution inserts a subshell, so $! is that subshell and the actual
# `yashiki subscribe` is its child. Killing only the subshell orphans the child,
# so kill it explicitly too.
# pgrep/pkill fail silently when directory services are wedged; walk ps instead.
kill_subscription() {  # pass nowait to skip the wait, which would hang in a trap
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

# Current geometry, held exactly as the subscription reports it.
#
# Compare geometry, not the set of ids. The bar's y_offset depends on how much
# the menu bar reserves, so the bar needs repositioning whenever that changes,
# even with the same displays attached.
#
# subscribe carries each display's state in the snapshot and in every event, so
# there is no need to re-read list-outputs. Doing so would ask for the same
# information twice and could disagree with the event being handled.
#
# Computing the gap needs each display's top inset. The usable area alone does
# not give it, but the stream also carries the physical rectangle:
#   inset = visible.y - physical.y
# No separate NSScreen lookup, which would give the value two different origins
# and require spawning a short-lived process to dodge AppKit's screen cache.
#
# is_main is kept as well: bar.lua's y_offset follows the main display's inset,
# so the bar has to move when main does, even if nothing else changed.
#
# No associative arrays. The shebang's bash is 3.2, which has no declare -A, so
# this is newline-separated "id=x,y,w,h,inset,is_main".
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

# Take in every display from a snapshot line
absorb_snapshot() {
  local id geom
  DISPLAY_GEOM=""
  while IFS='|' read -r id geom; do
    case "$id" in ''|*[!0-9]*) continue ;; esac
    geom_put "$id" "$geom"
  done < <(printf '%s' "$1" | jq -r '.displays[]? | "\(.id)|\(.x),\(.y),\(.width),\(.height),\(.y - .physical_y),\(if .is_main then 1 else 0 end)"' 2>/dev/null)
}

# Take in one display from a display_added or display_updated line
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

# The bar's y_offset and height, as bar.lua resolved them.
#
# Not --query bar. Until the configuration finishes loading, sketchybar answers
# with its defaults (y_offset=0, height=25). Those are plausible numbers, so a
# range check cannot reject them, and they come back steadily enough to pass a
# "same value twice" check too -- which is how gap.top ended up at 0+25+8=33
# instead of 8+32+8=48, leaving every window 15px too high and 7px of it behind
# the bar.
#
# bar.lua publishes the values it actually used. reset_bar_metrics removes the
# file before --reload, so a file that exists again can only have been written
# by the configuration that just loaded. No clock comparison, nothing to tune.
BAR_METRICS_FILE="$HOME/.cache/yashiki/bar_metrics"

reset_bar_metrics() {
  rm -f "$BAR_METRICS_FILE" 2>/dev/null || true
}

# Wait for bar.lua to publish, printing "y_offset height".
#
# A cold sketchybar takes a couple of seconds, and init starts it only at its
# very end, so the budget has to cover that: 60 * 0.2s = 12s. Normally the file
# is there on the first or second look.
wait_bar_metrics() {
  local i line yoff height
  for i in $(seq 1 60); do
    if [ -f "$BAR_METRICS_FILE" ]; then
      line=$(cat "$BAR_METRICS_FILE" 2>/dev/null)
      # Exactly two fields, or it is a partial write we should not trust
      case "$line" in
        *' '*' '*) ;;
        *' '*)
          yoff=${line%% *}
          height=${line##* }
          case "$yoff"   in ''|*[!0-9]*) yoff="" ;;   esac
          case "$height" in ''|*[!0-9]*) height="" ;; esac
          if [ -n "$yoff" ] && [ -n "$height" ] && [ "$height" -gt 0 ]; then
            printf '%s %s' "$yoff" "$height"
            return 0
          fi
          ;;
      esac
    fi
    sleep 0.2
  done
  return 1
}

# Hand the main display's inset to bar.lua.
#
# bar.lua adds it to y_offset; without it the bar hides behind the menu bar when
# that is always visible. sketchybar's y_offset is shared by all displays, so
# the main display is the right reference.
#
# bar.lua must not consult the OS itself. Deriving the value from yashiki's
# payload in one place and from NSScreen in another makes a disagreement
# impossible to trace.
#
# When the menu bar auto-hides, hand over 0. macOS keeps reserving the notch
# strip either way, but the bar can sit inside it: notch_width splits the items
# around the notch, which is how it renders. Passing the reservation through
# instead drops the bar below the strip and wastes the top 37px, and the windows
# follow the bar down with it.
#
# With the menu bar hidden the whole reservation is the notch, so there is no
# need to know the notch height separately. Deciding from geometry alone
# (reservation > safeAreaInsets.top) is possible but rests on a 0.5pt gap
# between a 38pt menu bar and a 37.5pt notch, which need not hold on every
# model.
publish_main_inset() {
  local inset
  # split "id=x,y,w,h,inset,is_main" on = and , -> $6=inset, $7=is_main
  inset=$(printf '%s' "$DISPLAY_GEOM" | grep -v '^$' \
    | awk -F'[=,]' '$7 == 1 { print $6; exit }')
  case "$inset" in ''|*[!0-9]*) return 0 ;; esac
  # An unset key means the macOS default, which is always visible
  if [ "$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null || echo 0)" = "1" ]; then
    inset=0
  fi
  mkdir -p "${INSET_FILE%/*}" 2>/dev/null || return 0
  printf '%s\n' "$inset" >"$INSET_FILE" 2>/dev/null || true
}

apply_outer_gaps() {
  local metrics yoff height base id inset top
  [ -x "$SKETCHYBAR" ] || return 0
  metrics=$(wait_bar_metrics) || {
    # bar.lua が書かなかった。設定のロードが落ちたか、reset のあと --reload が
    # 届かなかった。もう一度 reload して待ち直す。
    log "  bar.lua の metrics が出てこない -> reload をやり直す"
    reset_bar_metrics
    "$SKETCHYBAR" --reload >/dev/null 2>&1 </dev/null
    metrics=$(wait_bar_metrics) || {
      log "  metrics を取得できず gap 計算を見送り"
      return 0
    }
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

# Recompute the gaps and rebuild sketchybar when the geometry changed.
# --reload blanks the bar for a moment, so skip it when nothing moved.
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
  # Publish the inset first: bar.lua reads it during the reload, so writing it
  # afterwards would place the bar with the previous value.
  publish_main_inset
  # Drop the published metrics next, so whatever turns up afterwards is known to
  # come from the reload below and not from the configuration already running.
  reset_bar_metrics
  # Then reload. The gaps derive from the post-reload y_offset, so this order
  # cannot be swapped.
  [ -x "$SKETCHYBAR" ] && "$SKETCHYBAR" --reload >/dev/null 2>&1 </dev/null
  apply_outer_gaps
  return 0
}

# Open one subscription and read from it until it drops.
#
# Attach the process substitution to fd 3 with exec. Even on bash 3.2 that puts
# the child pid in $!, so it can be cleaned up on the way out. With
# `done < <(...)` the child cannot be reached and every reconnect leaks another
# subscribe. A FIFO does not work either: the reader sees EOF immediately while
# the writer is still alive.
subscribe_once() {
  local events pending quiet line rc spins window structural need why

  # --snapshot delivers every display's state on connect. That is the baseline,
  # so there is no list-outputs call at startup and no waiting for the
  # configuration to settle.
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
          # Full state at subscription time.
          #
          # Run settle here. init only starts sketchybar with exec --track and
          # never reloads it, so without this a sketchybar that came up before
          # the inset was written keeps the previous value.
          #
          # sketchybar need not be up yet: wait_bar_metrics inside
          # apply_outer_gaps waits up to twelve seconds for bar.lua to publish,
          # long enough for init to start it.
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

    # read returned non-zero. Do not use the return value to tell a timeout from
    # EOF: the shebang's bash is 3.2, where read -t returns 1 on timeout as well
    # (values above 128 arrived in bash 4.0). Testing for >128 on 3.2 mistakes
    # every one-second timeout for EOF and reconnects once a second.
    # Check whether the child is alive instead.
    if ! kill -0 "$SUB_PID" 2>/dev/null; then
      break
    fi

    # Child alive, so this was a timeout. If only the pipe closed, read keeps
    # returning immediately; reconnect once the rate departs from once a second.
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
  # Resolve again each round: the daemon may have been replaced
  YASHIKI=$(resolve_yashiki)

  # Check that the daemon is alive before subscribing.
  # Resetting the backoff on "the subscription lasted ten seconds" does not
  # work: with the daemon down, a failing subscribe takes about that long by
  # itself, so the condition holds and the backoff never takes effect.
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
