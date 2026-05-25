#!/bin/sh
input=$(cat)

# Directory (basename of cwd from JSON)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
dir=$(basename "$cwd")

# Model display name
model=$(echo "$input" | jq -r '.model.display_name // empty')

# Context remaining percentage
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Git branch (skip optional locks)
branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.fsmonitor=false symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" -c core.fsmonitor=false rev-parse --short HEAD 2>/dev/null)
fi

# Git status (dirty check)
git_dirty=""
if [ -n "$branch" ]; then
  if ! git -C "$cwd" -c core.fsmonitor=false diff --quiet 2>/dev/null || ! git -C "$cwd" -c core.fsmonitor=false diff --cached --quiet 2>/dev/null; then
    git_dirty="*"
  fi
fi

# Build status line
# Colors: directory=blue, git=bright-black, model=cyan, context=yellow
printf "\033[34m%s\033[0m" "$dir"

if [ -n "$branch" ]; then
  printf " \033[90m%s%s\033[0m" "$branch" "$git_dirty"
fi

if [ -n "$model" ]; then
  printf " \033[36m%s\033[0m" "$model"
fi

if [ -n "$remaining" ]; then
  printf " \033[33mctx:%s%%\033[0m" "$(printf '%.0f' "$remaining")"
fi
