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

## Window Manager Stack

[yashiki](https://github.com/typester/yashiki) tiles the windows; sketchybar draws
the bar and JankyBorders the window frames. yashiki owns the whole thing.

```
launchd  com.shsw228.yashiki
  └── yashiki  (runs ~/.config/yashiki/init on startup)
        ├── borders                          exec --track
        ├── sketchybar                       exec --track, started last
        │     └── yashiki_bridge.sh          started from sketchybarrc
        ├── display_watcher.sh
        └── focus_watcher.sh
```

Everything ends up in yashiki's process group, so launchd takes the whole stack
down together, including on a crash, and `KeepAlive` brings it back. This needs
`AbandonProcessGroup` left at its default in the LaunchAgent. Do not also start
borders or sketchybar from `brew services`: they have a single-instance guard and
the two copies collide.

### Who does what

| Component | Responsibility |
|---|---|
| `yashiki/init` | yashiki configuration, and starting the companions |
| `yashiki/display_watcher.sh` | Display geometry. Reloads sketchybar and applies the per-display outer gap |
| `yashiki/focus_watcher.sh` | Focus. Switches the borders colour and restores focus when it is lost |
| `sketchybar/plugins/yashiki_bridge.sh` | Translates yashiki events into sketchybar events |

yashiki has no event hooks — `exec` runs a command immediately — so anything that
reacts to state has to subscribe, which is why the watchers exist.

**The bridge translates only.** It must not write back to yashiki. Anything that
acts on yashiki belongs in a watcher. Mixing the two once made menu bar apps
dismiss their own menus: the bridge saw focus go nowhere, called `window-focus`,
and that activated a different app.

### Per-display gap

Displays reserve different amounts at the top: a notch keeps its strip even with
the menu bar hidden, an external display reserves nothing. sketchybar's `y_offset`
is shared by all of them, so `display_watcher.sh` computes the gap per display:

```
gap.top = y_offset + bar_height + WINDOW_MARGIN - inset
```

and writes the main display's inset to `~/.cache/yashiki/bar_inset`, which
`bar.lua` reads. Keeping a single source for that value matters — deriving it from
yashiki in one place and from `NSScreen` in another makes a disagreement
impossible to trace.

### yashiki build

Hotplugs work on upstream yashiki. Menu bar visibility changes and the per-display
gap need the fork at [shsw228/yashiki](https://github.com/shsw228/yashiki):
upstream emits no display event when the menu bar toggles, and its `OutputInfo`
carries no physical bounds, so the inset cannot be derived. `run_onchange_30`
prefers `/Applications/Yashiki-fork.app` when it is present and falls back to the
cask build otherwise.

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
