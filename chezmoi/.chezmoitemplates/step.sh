# TTY ではコマンドの出力をログへ逃がし、step の行だけを ✔/✖ に書き換えて見せる。
# 画面に残したい文言は say で出す（素の echo はログに入る）。対話が要る区間は step_raw にする。
# 後片付けは cleanup() を定義し直して行う（trap EXIT を上書きしない）。
_task={{ . | quote }}
_step=""
_raw=0
_log=""
_mark=0
exec 3>&2
if [ -t 2 ] && [ "${CHEZMOI_CI:-0}" != "1" ]; then _tty=1; else _tty=0; fi
if [ "$_tty" = "1" ]; then
  _log="$(mktemp -t dotfiles-run)"
  exec >>"$_log" 2>&1
fi

_captured() { [ "$_tty" = "1" ] && [ "$_raw" = "0" ]; }

_draw() {
  if _captured; then
    printf '\r\033[K  %b %s' "$1" "$_step" >&3
  else
    printf '  %b %s\n' "$1" "$_step" >&3
  fi
}

_end_step() {
  [ -n "$_step" ] || return 0
  if [ "$1" = "ok" ]; then
    [ "$_tty" = "1" ] && _draw '\033[32m✔\033[0m'
  else
    _draw '\033[31m✖\033[0m'
  fi
  if _captured; then printf '\n' >&3; fi
  _step=""
}

step() {
  _end_step ok
  if [ "$_tty" = "1" ] && [ "$_raw" = "1" ]; then exec >>"$_log" 2>&1; fi
  _raw=0
  _step="$1"
  [ -z "$_log" ] || _mark="$(wc -c <"$_log" | tr -d ' ')"
  _draw '\033[34m→\033[0m'
}

step_raw() {
  _end_step ok
  _raw=1
  exec 1>&3 2>&3
  _step="$1"
  _draw '\033[34m→\033[0m'
}

say() {
  if _captured && [ -n "$_step" ]; then printf '\r\033[K' >&3; fi
  printf '    %s\n' "$*" >&3
  if _captured && [ -n "$_step" ]; then _draw '\033[34m→\033[0m'; fi
}

# 長いコマンド用。出力の最新行を step の行に流し、止まっていないことを見せる。
progress() {
  if ! _captured; then
    "$@"
    return
  fi
  _rcf="$(mktemp)"
  { "$@" && echo 0 >"$_rcf" || echo $? >"$_rcf"; } 2>&1 \
    | tee -a "$_log" | tr '\r' '\n' | {
      cols="$(tput cols 2>/dev/null || echo 80)"
      width=$((cols - 8 - ${#_step} * 2))
      [ "$width" -ge 10 ] || width=10
      i=0
      while IFS= read -r l; do
        [ -n "$l" ] || continue
        f=$(set -- ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏; eval "printf %s \"\${$((i % 10 + 1))}\"")
        printf '\r\033[K  \033[34m%s\033[0m %s  \033[2m%s\033[0m' "$f" "$_step" \
          "$(printf '%s' "$l" | sed "s/$(printf '\033')\\[[0-9;]*[A-Za-z]//g" | cut -c "1-$width")" >&3
        i=$((i + 1))
      done
    }
  _prc="$(cat "$_rcf")"
  rm -f "$_rcf"
  _draw '\033[34m→\033[0m'
  return "$_prc"
}

cleanup() { :; }
_on_exit() {
  _rc=$?
  cleanup
  if [ "$_rc" -eq 0 ]; then
    _end_step ok
    printf '\033[32m✔\033[0m %s: 完了\n' "$_task" >&3
    [ -n "$_log" ] && rm -f "$_log"
  else
    _failed="$_step"
    _end_step ng
    if [ -n "$_log" ] && [ -s "$_log" ]; then
      tail -c "+$((_mark + 1))" "$_log" | tr '\r' '\n' | grep -v '^$' | tail -n 20 | sed 's/^/    │ /' >&3
      printf '    ログ全体: %s\n' "$_log" >&3
    fi
    printf '\033[31m✖\033[0m %s: %s失敗しました (exit %s)\n' \
      "$_task" "${_failed:+「${_failed}」で}" "$_rc" >&3
  fi
  exit "$_rc"
}
trap _on_exit EXIT
printf '\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$_task" >&3
