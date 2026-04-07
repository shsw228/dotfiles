{ pkgs, ... }:

{
  home.packages = with pkgs; [
    fzf
    zsh-completions
  ];

  programs.fzf.enable = true;

  programs.starship = {
    enable = true;
    settings = {
      format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$python$character";

      directory.style = "blue";

      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮](green)";
      };

      git_branch = {
        format = "[$branch]($style)";
        style = "bright-black";
      };

      git_status = {
        format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
        style = "cyan";
        conflicted = "";
        untracked = "";
        modified = "";
        staged = "";
        renamed = "";
        deleted = "";
        stashed = "󰏗";
      };

      git_state = {
        format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
        style = "bright-black";
      };

      cmd_duration = {
        format = "[$duration]($style) ";
        style = "yellow";
      };

      python = {
        format = "[$virtualenv]($style) ";
        style = "bright-black";
      };
    };
  };

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
          local repo="$(
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
                  | fzf --delimiter=$'\t' --with-nth=2.. --preview="ls -AF --color=always ''${root}/{1}" \
                  | cut -f1
          )"
          if [ -z "''${repo}" ]; then
              zle reset-prompt
              return
          fi

          local dir="''${root}/''${repo}"
          cd "''${dir}"
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
