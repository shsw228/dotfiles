{ username, ... }:

let
  taps = import ./homebrew/taps.nix;
  brews = import ./homebrew/brews.nix;
  casks = import ./homebrew/casks.nix;
in

{
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = username;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    user = username;
    enableZshIntegration = true;
    onActivation.cleanup = "uninstall";
    inherit taps brews casks;
  };
}
