#!/bin/sh
input=$(cat)

# Fallback when jq is unavailable.
if ! command -v jq >/dev/null 2>&1; then
  cwd="${PWD:-.}"
  dir=$(basename "$cwd")
  printf "\033[34m%s\033[0m" "$dir"
  exit 0
fi

# --- Extract fields from JSON -------------------------------------------------
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
[ -n "$cwd" ] || cwd="${PWD:-.}"
# Home-abbreviated full path (e.g. ~/Developer/.../Life)
case "$cwd" in
  "$HOME"*) dir="~${cwd#$HOME}" ;;
  *) dir="$cwd" ;;
esac

model=$(echo "$input" | jq -r '.model.display_name // empty')
style=$(echo "$input" | jq -r '.output_style.name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

# Rate limits (Pro/Max only; may be absent until first API response)
fh_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
fh_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
sd_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
sd_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- Git info (branch name only) ----------------------------------------------
branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  GIT="git -C $cwd -c core.fsmonitor=false"
  branch=$($GIT symbolic-ref --short HEAD 2>/dev/null || $GIT rev-parse --short HEAD 2>/dev/null)
fi

# Label color (bold, not gray) applied to every "label:" prefix.
L="\033[1m"   # bold
R="\033[0m"   # reset

# Format seconds-until-reset from an epoch: "2d3h" or "3h20m".
fmt_reset() {
  now=$(date +%s); d=$(( $1 - now ))
  [ "$d" -le 0 ] && return
  if [ "$d" -ge 86400 ]; then printf '%dd%dh' "$((d/86400))" "$(((d%86400)/3600))"
  else printf '%dh%02dm' "$((d/3600))" "$(((d%3600)/60))"; fi
}

# Solid 10-cell gauge using background colors (high contrast vs terminal bg).
# Usage: gauge <pct> <used|remain>
# Filled cells = bright colored bg; empty cells = same-hue dark bg (no gray).
gauge() {
  p=${1%%.*}; [ -z "$p" ] && p=0
  [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
  # Pick fill (bright) and track (dark) 256-colors from a red/yellow/green scale.
  if [ "$2" = remain ]; then
    if   [ "$p" -le 20 ]; then fill=196; track=52
    elif [ "$p" -le 50 ]; then fill=214; track=94
    else fill=39; track=24; fi
  else
    if   [ "$p" -ge 80 ]; then fill=196; track=52
    elif [ "$p" -ge 50 ]; then fill=214; track=94
    else fill=39; track=24; fi
  fi
  f=$(( (p + 5) / 10 )); [ "$f" -gt 10 ] && f=10
  i=0
  while [ "$i" -lt 10 ]; do
    if [ "$i" -lt "$f" ]; then printf '\033[48;5;%sm \033[0m' "$fill"
    else printf '\033[48;5;%sm \033[0m' "$track"; fi
    i=$((i+1))
  done
  printf ' \033[1;38;5;%sm%s%%\033[0m' "$fill" "$p"
}

# --- Line 1: model | branch | dir (no labels, pipe-separated) -----------------
# Colors: model=bright cyan, branch=bright magenta (+icon), directory=bright blue
PIPE=$(printf ' | ')
sep=""
if [ -n "$model" ]; then
  printf "\033[96m%s\033[0m" "$model"
  sep="$PIPE"
fi
if [ -n "$branch" ]; then
  printf "%s\033[95m\356\202\240 %s\033[0m" "$sep" "$branch"
  sep="$PIPE"
fi
printf "%s\033[94m%s\033[0m" "$sep" "$dir"

# --- Line 2: session (ctx / lines) --------------------------------------------
# Colors: style=magenta, context=yellow, diff=green/red
printf "\n"
sep=""

if [ -n "$style" ] && [ "$style" != "null" ] && [ "$style" != "default" ]; then
  printf "${L}style:${R}\033[35m%s\033[0m" "$style"
  sep=" "
fi

if [ -n "$added" ] || [ -n "$removed" ]; then
  printf "%s${L}lines:${R}\033[92m+%s\033[0m/\033[91m-%s\033[0m" "$sep" "${added:-0}" "${removed:-0}"
  sep=" "
fi

# --- Gauges: ctx / 5h / 7d, one per line, right-aligned labels (colons line up)
if [ -n "$remaining" ]; then
  printf "\n${L}%3s:${R}%s" "ctx" "$(gauge "$remaining" remain)"
fi

if [ -n "$fh_pct" ]; then
  left=$(fmt_reset "$fh_reset")
  printf "\n${L}%3s:${R}%s" "5h" "$(gauge "$fh_pct" used)"
  [ -n "$left" ] && printf " \033[36m(%s)\033[0m" "$left"
fi

if [ -n "$sd_pct" ]; then
  left=$(fmt_reset "$sd_reset")
  printf "\n${L}%3s:${R}%s" "7d" "$(gauge "$sd_pct" used)"
  [ -n "$left" ] && printf " \033[36m(%s)\033[0m" "$left"
fi
