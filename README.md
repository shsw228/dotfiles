# dotfiles

[![chezmoi-check](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml/badge.svg)](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml)

This repository is managed with `chezmoi`.

## Chezmoi Setup

1. Install and apply chezmoi with the official bootstrap

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply shsw228
```

2. If chezmoi is already installed, you can apply the same source directly

```sh
chezmoi init --apply shsw228
```

At `chezmoi init`, you will be asked whether this is a personal PC. If you answer `yes`, Git user settings are filled with personal defaults. If you answer `no`, `user.name` / `user.email` are requested interactively unless `GIT_NAME` / `GIT_EMAIL` are already set. In some environments, `chezmoi init` may not get a usable TTY for prompts, so explicit environment variables are the most reliable option for work machines.

For work machines, this non-interactive form is the most reliable:

```sh
CHEZMOI_IS_PERSONAL_PC=false \
GIT_NAME="Your Name" \
GIT_EMAIL="you@company.com" \
chezmoi init --apply shsw228
```

3. Confirm the installed `chezmoi` is looking at the expected source

```sh
chezmoi source-path
chezmoi status
```

The normal source path is `~/.local/share/chezmoi`. If `chezmoi diff` looks wrong, compare that directory with this repository's [`chezmoi/`](./chezmoi) before assuming your home directory drifted.

`chezmoi apply` will then:

- install Homebrew itself if `brew` is not present yet
- install packages from [`chezmoi/Brewfile`](./chezmoi/Brewfile)
- apply macOS preferences from `run_onchange_20_apply-macos-defaults.sh.tmpl`
- configure login items for Raycast and AeroSpace
- bootstrap the NotchNook license from 1Password when available
- place shell entrypoints such as `.zshenv`, `.zprofile`, and `.zshrc`, with their main contents under `~/.config/zsh/`
- place app config such as `~/.config/git/config`, `~/.config/nvim`, `~/.config/wezterm`, `~/.config/ghostty`, and `~/.config/aerospace/aerospace.toml`

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
