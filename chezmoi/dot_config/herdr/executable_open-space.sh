#!/usr/bin/env zsh
# shirube で選んだディレクトリの Space に移る。同じラベルの Space が無ければ作る。
target="$(shirube)" || exit 0
[[ -n "$target" ]] || exit 0
label="${target:t}"

id="$(herdr workspace list | jq -r --arg l "$label" '.result.workspaces[] | select(.label == $l) | .workspace_id' | head -1)"
if [[ -n "$id" ]]; then
  herdr workspace focus "$id" >/dev/null
else
  herdr workspace create --cwd "$target" --label "$label" --focus >/dev/null
fi
