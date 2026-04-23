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

At `chezmoi init`, you will be asked whether this is a personal PC. If you answer `yes`, Git user settings are filled with personal defaults. If you answer `no`, you can choose interactive input for work `user.name` / `user.email`; declining this exits with an error.

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
- place dotfiles such as `.zshrc`, `~/.gitconfig`, `~/.config/nvim`, `~/.config/wezterm`, and `~/.config/ghostty`
- place app config such as `~/.aerospace.toml`

For NotchNook, sign in to 1Password first, then run `chezmoi apply` again if the license has not been injected yet.

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
