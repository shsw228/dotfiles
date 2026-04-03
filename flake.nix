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
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
    }:

    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."hume" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home-manager/home.nix
        ];
      };
      darwinConfigurations."HumeBook-Air" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit self; }; # これがないとnix-darwinのモジュール内でhome-managerのモジュールを参照できない
        modules = [ ./nix-darwin/configuration.nix ];
      };
    };
}
