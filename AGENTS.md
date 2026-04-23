# Repository Guidelines

## Project Structure & Module Organization
This repository uses chezmoi with `.chezmoiroot` pointing at `chezmoi/`. The repository root is the expected source directory, and `chezmoi/` contains the source state.

Key entries include `chezmoi/Brewfile` for common Homebrew packages, `chezmoi/Brewfile.personal` for personal-only packages, `chezmoi/dot_config/` for XDG-style app configs, shell entrypoint stubs such as `chezmoi/dot_zshrc`, and bootstrap scripts such as `chezmoi/run_onchange_*.sh.tmpl`.

## Build, Test, and Development Commands
Run commands from the repository root.

- `chezmoi apply --source="$PWD"`: apply the current chezmoi source directly from this repo.
- `chezmoi status`: show drift between the source state and the home directory.
- `chezmoi source-path`: confirm which source directory the installed `chezmoi` is actually using.
- `brew bundle --file=chezmoi/Brewfile`: install or sync common packages without running the rest of chezmoi.

## Coding Style & Naming Conventions
Prefer small, explicit shell scripts and plain config files over clever abstractions. Keep shell scripts POSIX-friendly unless zsh-specific behavior is required. Match the current naming used by chezmoi: `dot_*` for required home-directory entrypoints, `dot_config/*` for `~/.config`, `remove_*` for files that must be removed, and `run_onchange_*` / `run_once_*` for scripts. Keep comments short and operational.

Prefer XDG locations when an app supports them. In this repository, Git config lives at `chezmoi/dot_config/git/config.tmpl`, AeroSpace lives at `chezmoi/dot_config/aerospace/aerospace.toml`, and zsh keeps only root-level stubs while the main shell files live under `chezmoi/dot_config/zsh/`.

## Testing Guidelines
There is no formal test suite. Validate changes by running `chezmoi diff --source="$PWD"` or `chezmoi apply --source="$PWD" --dry-run`. For shell updates, use `zsh -n` on zsh files and `sh -n` on POSIX shell scripts.

## Commit & Pull Request Guidelines
Use Japanese commit messages in the form `[type] summary`, for example `[refactor] chezmoiへ設定管理を移行`. Supported types are `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, and `ci`. In PRs, describe what moved, what was deleted, and which commands were used to verify the migration.

## Security & Configuration Tips
Do not commit secrets. 1Password bootstrap tokens, service account tokens, and app licenses must stay outside Git and be injected by local scripts. Treat `run_onchange_40_configure-notchnook-license.sh.tmpl` and related 1Password references as operational glue, not a place to store sensitive values. Do not commit local-only artifacts such as `.claude/`, `.DS_Store`, `result`, or stale chezmoi state copied from another source directory.
