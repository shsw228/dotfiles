# dotfiles

## Setup

On a new macOS machine, install Nix first and then apply `nix-darwin`.

1. Install Nix in multi-user mode

Official installer:

```sh
sh <(curl -L https://nixos.org/nix/install) --daemon
```

The official Nix manual recommends the multi-user installation on macOS.

Alternative:

- Install Determinate Nix if you prefer their installer flow

2. Clone this repository
3. Run the initial activation

```sh
darwin-rebuild switch --flake .#macOS
```

## 1Password Bootstrap

`1password` and `1password-cli` are installed through the Homebrew section managed by `nix-darwin`.

On a new machine, the intended flow is:

1. Run `darwin-rebuild switch --flake .#macOS`
2. Sign in to the 1Password GUI
3. Create a `Machine Bootstrap` item in the `Personal` vault
4. Store the service account token in the `service_account_token` field
5. Put `NotchNook License` in the `machine-secrets` vault
6. Run `darwin-rebuild switch --flake .#macOS` again

During the second activation, the activation script will:

- read the service account token from `Personal/Machine Bootstrap`
- create `~/.config/1password/service-account-token`
- read `machine-secrets/NotchNook License` through the service account
- re-inject `keyActive` into `NotchNook`

## Notes

- `nix-darwin/configuration.nix` sets `nix.enable = false;`, so Nix itself must be installed by an external installer
- Do not store secrets in this repository
