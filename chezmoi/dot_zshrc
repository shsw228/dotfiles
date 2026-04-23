setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt NOFLOWCONTROL

autoload -Uz add-zsh-hook
autoload -Uz chpwd_recent_dirs cdr

zstyle ':chpwd:*' recent-dirs-max 200
add-zsh-hook chpwd chpwd_recent_dirs

if command -v brew >/dev/null 2>&1; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

autoload -Uz compinit
compinit

if command -v sheldon >/dev/null 2>&1; then
  eval "$(sheldon source)"
fi

if (( $+functions[history-substring-search-up] && $+functions[history-substring-search-down] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi

if command -v fzf >/dev/null 2>&1; then
  case $- in
    *i*) eval "$(fzf --zsh)" ;;
  esac
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

alias vim="nvim"

case $- in
  *i*)
    function _fzf-select-history() {
      BUFFER=$(history -n -r 1 | fzf --style full --query "$LBUFFER" --reverse)
      CURSOR=$#BUFFER
      zle reset-prompt
    }
    zle -N _fzf-select-history
    bindkey '^f' _fzf-select-history

    function _fzf-cdr() {
      local selected_dir
      selected_dir=$(cdr -l | awk '{ print $2 }' | fzf --reverse)
      if [ -n "$selected_dir" ]; then
        BUFFER="cd ${selected_dir}"
        zle accept-line
      fi
      zle clear-screen
    }
    zle -N _fzf-cdr
    bindkey '^d' _fzf-cdr

    function _fzf_cd_ghq() {
      FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS} --reverse"
      local root
      local repo
      root="$(ghq root)"
      repo="$(
        ghq list \
          | awk -F/ '{
              full[NR] = $0
              owner = NF >= 2 ? $(NF - 1) : $0
              repo = $NF
              owners[NR] = owner
              repos[NR] = repo
              if (length(owner) > max_owner) {
                max_owner = length(owner)
              }
            }
            END {
              for (i = 1; i <= NR; i++) {
                printf "%s\t%-*s  %s\n", full[i], max_owner, owners[i], repos[i]
              }
            }' \
          | fzf --delimiter=$'\t' --with-nth=2.. --preview="ls -AF --color=always ${root}/{1}" \
          | cut -f1
      )"
      if [ -z "${repo}" ]; then
        zle reset-prompt
        return
      fi

      cd "${root}/${repo}" || return
      zle reset-prompt
    }
    zle -N _fzf_cd_ghq
    bindkey '^r' _fzf_cd_ghq
    ;;
esac

if [ -f "$HOME/.local/bin/env" ]; then
  . "$HOME/.local/bin/env"
fi
