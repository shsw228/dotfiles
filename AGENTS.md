# Repository Guidelines

## Project Structure & Module Organization
This repository is centered on `chezmoi/`. It contains the source state for shell files, app configs, and bootstrap scripts. Key entries include `dot_zshrc`, `dot_zshenv`, `dot_config/`, `Brewfile`, and `run_onchange_*.sh.tmpl`.

## Build, Test, and Development Commands
Run commands from the repository root.

- `chezmoi apply --source="$PWD/chezmoi"`: apply the current chezmoi source directly from this repo.
- `chezmoi status`: show drift between the source state and the home directory.
- `chezmoi source-path`: confirm which source directory the installed `chezmoi` is actually using.
- `brew bundle --file=chezmoi/Brewfile`: install or sync packages without running the rest of chezmoi.

## Coding Style & Naming Conventions
Prefer small, explicit shell scripts and plain config files over clever abstractions. Keep shell scripts POSIX-friendly unless zsh-specific behavior is required. Match the current naming used by chezmoi: `dot_*` for home files, `dot_config/*` for `~/.config`, and `run_onchange_*` / `run_once_*` for scripts. Keep comments short and operational.

## Testing Guidelines
There is no formal test suite. Validate changes by running `chezmoi diff` or `chezmoi apply --dry-run`. For shell updates, use `zsh -n chezmoi/dot_zshrc` or `sh -n` on scripts.

## Commit & Pull Request Guidelines
Use Japanese commit messages in the form `[type] summary`, for example `[refactor] chezmoiへ設定管理を移行`. Supported types are `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, and `ci`. In PRs, describe what moved, what was deleted, and which commands were used to verify the migration.

## Security & Configuration Tips
Do not commit secrets. 1Password bootstrap tokens, service account tokens, and app licenses must stay outside Git and be injected by local scripts. Treat `run_onchange_40_configure-notchnook-license.sh.tmpl` and related 1Password references as operational glue, not a place to store sensitive values. Do not commit local-only artifacts such as `.claude/`, `result`, or stale chezmoi state copied from another source directory.
