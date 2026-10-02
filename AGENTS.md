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

Prefer XDG locations when an app supports them. In this repository, Git config lives at `chezmoi/dot_config/git/config.tmpl`, and zsh keeps only root-level stubs while the main shell files live under `chezmoi/dot_config/zsh/`.

## Testing Guidelines
There is no formal test suite. Validate changes by running `chezmoi diff --source="$PWD"` or `chezmoi apply --source="$PWD" --dry-run`. For shell updates, use `zsh -n` on zsh files and `sh -n` on POSIX shell scripts.

## Commit & Pull Request Guidelines
Use Japanese commit messages in the form `[type] summary`, for example `[refactor] chezmoiへ設定管理を移行`. Supported types are `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `build`, and `ci`. In PRs, describe what moved, what was deleted, and which commands were used to verify the migration.

## Monitor KVM (Dell U4025QW)

`chezmoi/dot_local/bin/executable_kvm` switches the monitor's built-in KVM — which machine owns the USB upstream — over DDC/CI. It is driven by `betterdisplaycli` (Homebrew: `waydabber/betterdisplay/betterdisplaycli`), so BetterDisplay must be running.

The monitor's own capabilities string is the authority on what DDC can do. Read it with `betterdisplaycli get -name="DELL U4025QW" -ddcCapabilitiesString`, and get a decoded report with `-ddcCapabilities`. Do not guess VCP codes from other models.

What was verified on this monitor:

- `0xE7` is the USB/KVM switch. Writing `0xFF00` (decimal `65280`) hands USB to the other input. **It is a toggle only** — there is no way to address a side directly.
- The code always reads back as `0xBC00` regardless of state, so DDC cannot report where USB currently is. The script does not try to find out: toggling is the only operation it offers.
- The values the capabilities string lists for `0xE7` (`02 03`) are not writable values — they do nothing. Verified by probing.
- Other confirmed codes: `0x60` input select (`0x19` Thunderbolt, `0x0F` DP, `0x11` HDMI), `0xE9` PIP/PBP mode (`0x00` single, `0x24` PBP), `0x10` brightness, `0x12` contrast.

Take care when testing: switching USB away detaches the keyboard and mouse from this Mac, and the only way back is the other machine or the monitor's OSD joystick. Wrap any probe in a script that reverts itself rather than switching interactively.

`chezmoi/dot_local/share/raycast/scripts/` holds a thin Raycast script command that calls `kvm`. Raycast does not discover it on its own — the directory has to be registered once per machine under Settings → Extensions → Add Script Directory. The wrapper calls `kvm` by absolute path and the script falls back to `/opt/homebrew/bin/betterdisplaycli`, because Raycast does not inherit the shell's PATH.

## Security & Configuration Tips
Do not commit secrets. 1Password bootstrap tokens, service account tokens, and app licenses must stay outside Git and be injected by local scripts. Treat 1Password references in scripts as operational glue, not a place to store sensitive values. Do not commit local-only artifacts such as `.claude/`, `.DS_Store`, `result`, or stale chezmoi state copied from another source directory.
