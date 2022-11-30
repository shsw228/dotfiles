#!/bin/bash

# スクリプトが存在するディレクトリを元に.から始まるファイルを検索してシンボリックリンクを張る
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for dotfile in "${SCRIPT_DIR}"/.??* ; do
    [[ "$dotfile" == "${SCRIPT_DIR}/.git" ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.github" ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.DS_Store" ]] && continue
    
    ln -fnsv "$dotfile" "$HOME"
done
ln -fnsv "${SCRIPT_DIR}/starship.toml" "$HOME/.config" 

echo "✅ link.sh is done."
