{
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  imports = [
    ./ghostty.nix
    ./karabiner.nix
    ./nvim.nix
    ./wezterm.nix
    ./zsh.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "25.11"; # Please read the comment before changing.
  home.packages = with pkgs; [
    # CLI tools
    aria2
    bat
    gh
    ghq
    git
    gitflow
    gnumake
    home-manager
    lazygit
    lua
    nixfmt
    nodejs
    pnpm
    tree-sitter
    xcodes

    # Terminal/editor
    _1password-cli
    codex
    github-copilot-cli
    neovim
  ];
  home.file = {
    ".config/git/config".source = ./git/config;
    ".config/git/ignore".source = ./git/ignore;
  };
  home.sessionVariables = { };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
