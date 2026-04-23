# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/). The `.chezmoiroot` file points chezmoi's source state to the `chezmoi/` directory.

## Common Commands

```sh
# Apply from this repo (not the default chezmoi source)
chezmoi apply --source="$PWD"

# Preview changes without applying
chezmoi diff --source="$PWD"
chezmoi apply --source="$PWD" --dry-run

# Show drift between source and home
chezmoi status

# Install/sync Homebrew packages only
brew bundle --file=chezmoi/Brewfile

# Syntax-check shell files before committing
sh -n chezmoi/run_onchange_*.sh.tmpl chezmoi/run_once_*.sh.tmpl
zsh -n chezmoi/dot_zshrc chezmoi/dot_zshenv chezmoi/dot_zprofile
zsh -n chezmoi/dot_config/zsh/dot_z*
```

## CI

`chezmoi-check` workflow (`.github/workflows/chezmoi-check.yml`) runs on PRs and pushes to main. It validates template rendering, dry-run apply, expected managed targets, and shell syntax. Ensure `chezmoi apply --dry-run` and all `sh -n`/`zsh -n` checks pass before merging.

## Source Layout

- `chezmoi/` — chezmoi source state (`.chezmoiroot` makes this the root)
  - `dot_config/` — XDG `~/.config` targets (git, zsh, nvim, aerospace, ghostty, wezterm, karabiner, sheldon, starship)
  - `dot_zshrc`, `dot_zshenv`, `dot_zprofile` — thin stubs that source `~/.config/zsh/`
  - `Brewfile` / `Brewfile.personal` — Homebrew packages (common / personal-only); ignored by chezmoi via `.chezmoiignore`
  - `run_once_*` / `run_onchange_*` — bootstrap scripts (Homebrew install, packages, macOS defaults, login items, NotchNook license)
  - `.chezmoi.toml.tmpl` — config template; prompts for personal vs work PC, sets git identity
  - `remove_*` — files chezmoi will delete from `$HOME`

## Conventions

- **Chezmoi naming**: `dot_*` for home-dir entries, `dot_config/*` for `~/.config`, `remove_*` for deletion, `run_onchange_*`/`run_once_*` for scripts
- **XDG-first**: prefer `~/.config/<app>/` when the app supports it
- **Shell scripts**: POSIX-friendly unless zsh-specific behavior is needed
- **Templates**: `.tmpl` suffix for chezmoi Go templates; use `.data.profile.is_personal_pc` and `.data.git.*` for conditional content

## Commit Messages

Japanese, in the form `[type] 概要`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`. PR titles also in Japanese.

## Secrets

Never commit secrets. 1Password tokens and app licenses are injected at runtime by `run_onchange_*` scripts, not stored in source.
