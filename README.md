# dotfiles

This repository is managed with `chezmoi` for dotfiles and `nix-darwin` only for the remaining macOS-specific modules.

## Current Direction

- New setup work should go through [`chezmoi/`](./chezmoi)
- `chezmoi/` is the source of truth for shell, editor, and user dotfiles
- `chezmoi/Brewfile` is the only package inventory
- `nix-darwin/` remains only for modules that are not yet worth moving
- Secrets must stay out of Git

## Chezmoi Setup

1. Install and apply chezmoi with the official bootstrap

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply shsw228 --source="$HOME/Developer/ghq/github.com/shsw228/dotfiles/chezmoi"
```

This installs chezmoi itself first, then applies this repository as the source directory.

2. If chezmoi is already installed, you can apply the same source directly

```sh
chezmoi init --apply --source="$HOME/Developer/ghq/github.com/shsw228/dotfiles/chezmoi"
```

`chezmoi apply` will then:

- install Homebrew itself if `brew` is not present yet
- install packages from [`chezmoi/Brewfile`](./chezmoi/Brewfile)
- apply macOS preferences from `run_onchange_20_apply-macos-defaults.sh.tmpl`
- configure login items for Raycast and AeroSpace
- bootstrap the NotchNook license from 1Password when available
- place dotfiles such as `.zshrc`, `~/.gitconfig`, `~/.config/nvim`, `~/.config/wezterm`, and `~/.config/ghostty`
- place app config such as `~/.aerospace.toml`
- supersede the removed Home Manager-managed shell/editor dotfiles

For NotchNook, sign in to 1Password first, then run `chezmoi apply` again if the license has not been injected yet.

## Codex

`codex` is managed outside Nix in the chezmoi path. The package list currently installs it with Homebrew, so updates are straightforward:

```sh
brew upgrade codex
```

If you prefer the npm distribution instead, remove `brew "codex"` from `chezmoi/Brewfile` and use `npm install -g @openai/codex`.

## Legacy Nix Setup

The flake-based setup still exists for the remaining `nix-darwin` modules:

```sh
darwin-rebuild switch --flake .#macOS
```

This no longer configures shell/editor dotfiles, Homebrew packages, macOS `defaults`, AeroSpace, Raycast, or NotchNook; those are handled by `chezmoi`.
