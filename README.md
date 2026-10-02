# dotfiles

[![chezmoi-check](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml/badge.svg)](https://github.com/shsw228/dotfiles/actions/workflows/chezmoi-check.yml)

macOS dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Fresh Machine Setup

### 1. Bootstrap with chezmoi (HTTPS)

The repo is public, so the initial clone needs no SSH key or 1Password. Clone over HTTPS; `chezmoi apply` then installs Homebrew, the Brewfile (including 1Password), and all config.

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply \
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
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply \
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
- configure the Tinycast login item
- place shell entrypoints such as `.zshenv`, `.zprofile`, and `.zshrc`, with their main contents under `~/.config/zsh/`
- place app config such as `~/.config/git/config`, `~/.config/nvim`, and `~/.config/ghostty`
- create `~/.1password-agent.sock` symlink (avoids space-in-path issue with the 1Password socket)
- register `SSH_AUTH_SOCK` in launchd via `~/Library/LaunchAgents/com.shsw228.ssh-auth-sock.plist` so GUI clients can use the 1Password agent
- deploy `~/.ssh/config` so `github.com` uses the persona SSH key via the 1Password agent (personal key on personal PCs, work key on work PCs)
- on work PCs, deploy `~/.config/git/config.personal` and `~/.ssh/config_personal` so repositories under `~/Developer/ghq/github.com/shsw228/` still use the personal identity and key

## Window Manager Stack

[AeroSpace](https://github.com/nikitabobko/AeroSpace) tiles the windows and
[JankyBorders](https://github.com/FelixKratz/JankyBorders) draws the window frames.
There is no status bar — the macOS menu bar is used as-is.

```
launchd  com.shsw228.aerospace
  └── AeroSpace  (reads ~/.config/aerospace/aerospace.toml)
        └── borders        after-startup-command, exec-and-forget
```

`run_onchange_30_configure-login-items.sh.tmpl` writes the LaunchAgent and
bootstraps it. `start-at-login` stays `false` in the config because launchd owns
the lifecycle; turning both on gives you two instances.

Do not start `borders` from `brew services` as well. AeroSpace launches it from
`after-startup-command`, and the two copies collide on its single-instance guard.

Which WM the login-items script configures comes from `wm.kind` in
`~/.config/chezmoi/chezmoi.toml` (default `aerospace`). Set `CHEZMOI_WM` and
re-run `chezmoi init` to try another one.

### Workspaces

Workspaces are named, not numbered: `1.Browser`, `2.Terminal`, `3.Editor`,
`4.AI`, `5`–`9`, `10.Music`. They are declared `persistent-workspaces`, so they
exist even when empty.

### Keys

`alt` is the modifier. `alt-h/j/k/l` moves focus, `alt-shift-h/j/k/l` moves the
window, `alt-o` switches monitor. Full list in
[`chezmoi/dot_config/aerospace/aerospace.toml`](./chezmoi/dot_config/aerospace/aerospace.toml).

## Monitor KVM

`~/.local/bin/kvm` drives a Dell U4025QW over DDC/CI, via `betterdisplaycli`.
BetterDisplay must be running.

```sh
kvm usb toggle    # hand USB to the other input (toggle)
kvm input tb      # show the Thunderbolt input
kvm input hdmi    # show the HDMI input
```

USB only toggles. The monitor reports the same value for the KVM code no matter
which side owns USB, so neither the script nor anything else can address a side
directly or report where USB currently is. Handing USB away detaches this Mac's
keyboard and mouse; the only way back is the other machine or the OSD joystick.

The video input can be set directly, and the write works even from the Mac that
is not on screen. The display's UUID is cached in `~/.cache/kvm/uuid` because the
display cannot be looked up by name while it is detached.

## Local-Only Configuration

The following files are loaded if present but not managed by chezmoi, so `chezmoi apply` will not overwrite them. Useful for machine-specific settings you don't want in a public repository.

- `~/.config/zsh/local.zsh` — sourced at the end of `.zshrc`
- `~/.config/git/config.local` — included via `[include]` at the end of git config

`~/.config/git/config.personal` looks similar but **is** managed by chezmoi. It is
pulled in by an `includeIf` that only fires for repositories under
`~/Developer/ghq/github.com/shsw228/`, and exists because a work PC otherwise
commits to personal repositories with the work identity and the work SSH key.

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
