if [ `uname -m` = "arm64" ]; then
export PATH=/opt/homebrew/bin:$PATH
export PATH=/bin:$PATH
else
export PATH=/usr/local/bin/brew:$PATH
fi


# github cli Completion
eval "$(gh completion -s zsh)"

# history
HISTFILE=$HOME/.zsh-history # 履歴を保存するファイル
HISTSIZE=100000             # メモリ上に保存する履歴のサイズ
SAVEHIST=1000000            # 上述のファイルに保存する履歴のサイズ

# share .zshhistory
setopt inc_append_history   # 実行時に履歴をファイルにに追加していく
setopt share_history        # 履歴を他のシェルとリアルタイム共有する

# Monterey以降pythonコマンドが存在しないためのエイリアス
alias python="python3"


 if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source $(brew --prefix)/opt/zsh-git-prompt/zshrc.sh    

	autoload -Uz compinit && compinit
	autoload -Uz colors && colors
 fi


# 補完候補をそのまま探す -> 小文字を大文字に変えて探す -> 大文字を小文字に変えて探す
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' '+m:{[:upper:]}={[:lower:]}'

### 補完方法毎にグループ化する。
zstyle ':completion:*' format '%B%F{blue}%d%f%b'
zstyle ':completion:*' group-name ''


setopt correct
SPROMPT="correct: $RED%R$DEFAULT -> $GREEN%r$DEFAULT ? [Yes/No/Abort/Edit] => "

PROMPT="%F{green}%n%f %F{cyan}($(arch))%f:%F{blue}%~%f"$'\n'"%# "

PROMPT='%F{034}%n%f %F{036}($(arch))%f:%F{020}%~%f $(git_super_status)'
PROMPT+=""$'\n'"%# "

add_newline() {
  if [[ -z $PS1_NEWLINE_LOGIN ]]; then
    PS1_NEWLINE_LOGIN=true
  else
    printf '\n'
  fi
}
precmd() { add_newline }
