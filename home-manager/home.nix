{
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  imports = [
    ./zsh.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "25.11"; # Please read the comment before changing.
  home.packages = with pkgs; [
    bat
    gh
    ghq
    git
    nixfmt
  ];
  home.file = {
    ".config/git/config".source = ./git/config;
    ".config/git/ignore".source = ./git/ignore;
  };
  home.sessionVariables = { };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
