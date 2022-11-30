if [ `uname -m` = "arm64" ]; then
export PATH=/opt/homebrew/bin:$PATH
export PATH=/bin:$PATH
else
export PATH=/usr/local/bin/brew:$PATH
fi

export LANG=ja_JP.UTF-8


# github cli Completion
eval "$(gh completion -s zsh)"

# history
HISTFILE=$HOME/.zsh-history # 履歴を保存するファイル
HISTSIZE=100000             # メモリ上に保存する履歴のサイズ
SAVEHIST=1000000            # 上述のファイルに保存する履歴のサイズ

# share .zshhistory
setopt inc_append_history   # 実行時に履歴をファイルにに追加していく
setopt share_history        # 履歴を他のシェルとリアルタイム共有する
setopt hist_reduce_blanks	   # 履歴に空白を入れない
setopt hist_ignore_all_dups # 履歴を重複しない

# Monterey以降pythonコマンドが存在しないためのエイリアス
alias python="python3"


 if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
    source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    

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


alias ls="ls -FG"
alias ll="ls -l"
alias lla="ls -la"

gas() {
  git add -A;
  git status;
}

alias gcm="git commit -m"

# Github CLIを利用して最初の諸々をいいかんじにする　ref:https://zenn.dev/torahack/articles/d6b760fd11bf3a

gcre() {
    git init && git add . && git status && git commit -m "First commit"
    echo "Type repository name: " && read name;
    echo "Type repository description: " && read description;
    gh repo create ${name} --description ${description}
    git remote add origin https://github.com/deatiger/${name}.git
    git checkout -b develop;
    git push -u origin develop;
}

eval "$(starship init zsh)"
