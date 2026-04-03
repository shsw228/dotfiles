{
  username,
  homeDirectory,
  ...
}:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "before-home-manager";
  home-manager.extraSpecialArgs = {
    inherit
      username
      homeDirectory
      ;
  };
  home-manager.users.${username} = {
    imports = [
      ../home-manager/home.nix
    ];
  };
}
