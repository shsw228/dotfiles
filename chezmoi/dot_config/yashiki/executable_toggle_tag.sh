#!/bin/sh
# window-toggle-tag のラッパー:
#   focus 中 window が指定 tag をまだ持っていなければ → toggle (= 追加) して
#   そのまま tag-view で view を追従。
#   既に持っていれば → toggle (= 削除) のみ。view は動かさない。
#
# Usage: toggle_tag.sh <bitmask>

set -eu

YASHIKI="/opt/homebrew/bin/yashiki"
target="${1:?usage: $(basename "$0") <bitmask>}"

fid=$("$YASHIKI" focused-window 2>/dev/null || true)
if [ -z "$fid" ]; then
  # focus が無いときは tag 操作だけ
  "$YASHIKI" window-toggle-tag "$target" >/dev/null 2>&1 || true
  exit 0
fi

# 該当 window の tags を list-windows から拾う
cur_tags=$("$YASHIKI" list-windows 2>/dev/null \
  | grep -E "^${fid}:" \
  | sed -E 's/.*tags=([0-9]+).*/\1/' \
  | head -1)

will_add=1
if [ -n "${cur_tags:-}" ] && [ $(( cur_tags & target )) -ne 0 ]; then
  will_add=0   # 既に所属 → 削除方向
fi

"$YASHIKI" window-toggle-tag "$target" >/dev/null 2>&1 || true

if [ "$will_add" -eq 1 ]; then
  "$YASHIKI" tag-view "$target" >/dev/null 2>&1 || true
fi
