#!/bin/sh
# 1Password から SSH config と公開鍵を取得して ~/.ssh/ に配置する
# 前提: 1Password アプリ + CLI が有効化済み
set -eu

OP_PERSONAL="op://Personal/gfvmrwe4atklvfys2zfme6ntta"
OP_WORK="op://works/z3snaspopwwg33r6rcrtdjc6iy"

if ! command -v op >/dev/null 2>&1; then
  echo "op CLI が見つかりません。1Password の設定 → 開発者 → CLI を有効化してください" >&2
  exit 1
fi

mkdir -p ~/.ssh
chmod 700 ~/.ssh

op read "${OP_PERSONAL}/ssh_config" > ~/.ssh/config
chmod 600 ~/.ssh/config
echo "~/.ssh/config を配置しました"

op read "${OP_PERSONAL}/public key" > ~/.ssh/github_personal.pub
chmod 644 ~/.ssh/github_personal.pub
echo "~/.ssh/github_personal.pub を配置しました"

op read "${OP_WORK}/public_key" > ~/.ssh/github_work.pub
chmod 644 ~/.ssh/github_work.pub
echo "~/.ssh/github_work.pub を配置しました"

echo ""
echo "確認:"
ssh -T git@github.com || true
