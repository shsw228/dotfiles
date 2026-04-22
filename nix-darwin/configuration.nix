{
  pkgs,
  username,
  homeDirectory,
  self,
  ...
}:
{
  system = {
    stateVersion = "6";
    configurationRevision = self.rev or self.dirtyRev or null;
    primaryUser = username;
  };
  users.users.${username}.home = homeDirectory;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    hack-font
    moralerspace
    nerd-fonts.hack
  ];

  nix.enable = false;
  environment.systemPackages = with pkgs; [
    # GUI applications
    _1password-gui
    ghostty-bin
    google-chrome
    raycast
    vscode
    wezterm
  ];

  programs.zsh.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;
}
