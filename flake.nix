{
  description = "Home Manager configuration of hume";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      nix-homebrew,
    }:
    let
      username = "hume";
      homeDirectory = "/Users/${username}";
    in
    {

      darwinConfigurations."macOS" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit
            self
            username
            homeDirectory
            ;
        }; # flakeのリビジョン情報と共通ユーザー設定を各モジュールから参照する
        modules = [
          ./nix-darwin/configuration.nix
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
        ];
      };
    };
}
