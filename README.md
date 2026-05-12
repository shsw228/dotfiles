# dotfiles

[![chezmoi-check](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml/badge.svg)](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml)

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Fresh Machine Setup

### 1. Prepare 1Password and SSH

1. Install [1Password](https://apps.apple.com/app/1password-7-password-manager/id1333542190)
2. Enable **SSH Agent** and **CLI** in 1Password Settings → Developer
3. Run the bootstrap script to pull public keys from 1Password

```sh
curl -fsSL https://raw.githubusercontent.com/shsw228/dotfiles/main/setup-ssh.sh | sh
```

This places `~/.ssh/github_personal.pub`, `~/.ssh/github_work.pub`, and a minimal `~/.ssh/config` good enough to clone the dotfiles repo over SSH. The full `~/.ssh/config` is managed by chezmoi and will overwrite this bootstrap on `chezmoi apply`.

### 2. Bootstrap with chezmoi

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:shsw228/dotfiles.git
```

During `chezmoi init`, you will be asked whether this is a personal PC.

- **Personal PC** → `yes` (Git identity is filled automatically)
- **Work PC** → `no` (`user.name` / `user.email` prompted interactively)

Non-interactive form for work machines:

```sh
CHEZMOI_IS_PERSONAL_PC=false \
GIT_NAME="Your Name" \
GIT_EMAIL="you@company.com" \
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply git@github.com:shsw228/dotfiles.git
```

### 3. Verify

```sh
chezmoi source-path
chezmoi status
```

`chezmoi apply` will then:

- install Homebrew itself if `brew` is not present yet
- install packages from [`chezmoi/Brewfile`](./chezmoi/Brewfile)
- apply macOS preferences from `run_onchange_20_apply-macos-defaults.sh.tmpl`
- configure login items for Raycast and AeroSpace
- bootstrap the NotchNook license from 1Password when available
- place shell entrypoints such as `.zshenv`, `.zprofile`, and `.zshrc`, with their main contents under `~/.config/zsh/`
- place app config such as `~/.config/git/config`, `~/.config/nvim`, `~/.config/wezterm`, `~/.config/ghostty`, and `~/.config/aerospace/aerospace.toml`
- create `~/.1password-agent.sock` symlink (avoids space-in-path issue with the 1Password socket)
- register `SSH_AUTH_SOCK` in launchd via `~/Library/LaunchAgents/com.shsw228.ssh-auth-sock.plist` so GUI clients can use the 1Password agent
- deploy `~/.ssh/config` with `github.com` (defaults to work key on work PCs / personal key on personal PCs) and `github.com-personal` / `github.com-work` host aliases
- rewrite remote URLs for repos under `shsw228/` to use the `github.com-personal` alias via `[url ... insteadOf]`

For NotchNook, sign in to 1Password first, then run `chezmoi apply` again if the license has not been injected yet.

## Local-Only Configuration

The following files are loaded if present but not managed by chezmoi, so `chezmoi apply` will not overwrite them. Useful for machine-specific settings you don't want in a public repository.

- `~/.config/zsh/local.zsh` — sourced at the end of `.zshrc`
- `~/.config/git/config.local` — included via `[include]` at the end of git config

## Daily Use

```sh
chezmoi status
chezmoi diff
chezmoi apply
```

For package-only changes, you can also run:

```sh
brew bundle --file=chezmoi/Brewfile
```
