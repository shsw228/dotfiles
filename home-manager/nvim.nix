{
  config,
  homeDirectory,
  ...
}:

{
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${homeDirectory}/ghq/github.com/shsw228/dotfiles/home-manager/nvim";
}
