{ pkgs, ... }:

{
  home.packages = with pkgs; [
    fzf
    zsh-completions
  ];

  programs.fzf.enable = true;

  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    historySubstringSearch.enable = true;
    syntaxHighlighting.enable = true;
    setOptions = [
      "HIST_IGNORE_ALL_DUPS"
      "HIST_SAVE_NO_DUPS"
      "HIST_IGNORE_SPACE"
      "NOFLOWCONTROL"
    ];
    shellAliases = {
      vim = "nvim";
    };
    initContent = ''
      function _fzf-select-history() {
          BUFFER=$(history -n -r 1 | fzf --style full --query "$LBUFFER" --reverse)
          CURSOR=$#BUFFER
          zle reset-prompt
      }
      zle -N _fzf-select-history
      bindkey '^f' _fzf-select-history

      function _fzf-cdr() {
          local selected_dir=$(cdr -l | awk '{ print $2 }' | fzf --reverse)
          if [ -n "$selected_dir" ]; then
              BUFFER="cd ''${selected_dir}"
              zle accept-line
          fi
          zle clear-screen
      }
      zle -N _fzf-cdr
      bindkey '^d' _fzf-cdr

      function _fzf_cd_ghq() {
          FZF_DEFAULT_OPTS="''${FZF_DEFAULT_OPTS} --reverse"
          local root="$(ghq root)"
          local repo="$(ghq list | fzf --preview="ls -AF --color=always ''${root}/{1}")"
          local dir="''${root}/''${repo}"
          [ -n "''${dir}" ] && cd "''${dir}"
          zle accept-line
          zle reset-prompt
      }

      zle -N _fzf_cd_ghq
      bindkey "^r" _fzf_cd_ghq
      export PATH="/opt/homebrew/bin:$PATH"

      if [ -f "$HOME/.local/bin/env" ]; then
        . "$HOME/.local/bin/env"
      fi
    '';
  };
}
