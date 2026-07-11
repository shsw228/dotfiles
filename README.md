# dotfiles

[![chezmoi-check](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml/badge.svg)](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml)

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Fresh Machine Setup

### 1. Bootstrap with chezmoi (HTTPS)

The repo is public, so the initial clone needs no SSH key or 1Password. Clone over HTTPS; `chezmoi apply` then installs Homebrew, the Brewfile (including 1Password), and all config.

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
  --source="$HOME/Developer/ghq/github.com/shsw228/dotfiles" \
  https://github.com/shsw228/dotfiles.git
```

During `chezmoi init`, you will be asked whether this is a personal PC.

- **Personal PC** → `yes` (Git identity is filled automatically)
- **Work PC** → `no` (`user.name` / `user.email` prompted interactively)

Non-interactive form for work machines:

```sh
CHEZMOI_IS_PERSONAL_PC=false \
GIT_NAME="Your Name" \
GIT_EMAIL="you@company.com" \
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
  --source="$HOME/Developer/ghq/github.com/shsw228/dotfiles" \
  https://github.com/shsw228/dotfiles.git
```

### 2. Enable the 1Password SSH agent (when prompted)

Near the end of `chezmoi apply`, a finalize step pauses with a spinner and asks you to:

1. Open 1Password (installed by the Brewfile — no `op` CLI needed), sign in, and unlock it
2. Settings → Developer → enable **Use the SSH agent**

As soon as the agent is reachable, the step automatically switches the dotfiles remote from HTTPS to SSH (`git@github.com:…`) so future pull/push go through the agent, then `chezmoi apply` finishes. `~/.ssh/config` (placed by chezmoi) already points `IdentityAgent` at the app socket, so keys stay in your vault — none on disk.

On non-interactive runs (CI, no TTY) this step is skipped, and it times out after ~5 minutes if left unattended.

### 3. Verify

```sh
chezmoi source-path
chezmoi status
```

`chezmoi apply` will then:

- install Homebrew itself if `brew` is not present yet
- install packages from [`chezmoi/Brewfile`](./chezmoi/Brewfile)
- apply macOS preferences from `run_onchange_20_apply-macos-defaults.sh.tmpl`
- configure the Raycast login item
- place shell entrypoints such as `.zshenv`, `.zprofile`, and `.zshrc`, with their main contents under `~/.config/zsh/`
- place app config such as `~/.config/git/config`, `~/.config/nvim`, `~/.config/wezterm`, and `~/.config/ghostty`
- create `~/.1password-agent.sock` symlink (avoids space-in-path issue with the 1Password socket)
- register `SSH_AUTH_SOCK` in launchd via `~/Library/LaunchAgents/com.shsw228.ssh-auth-sock.plist` so GUI clients can use the 1Password agent
- deploy `~/.ssh/config` so `github.com` uses the persona SSH key via the 1Password agent (personal key on personal PCs, work key on work PCs)

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
