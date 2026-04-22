{
  description = "macOS dotfiles managed with chezmoi and nix-darwin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
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
        ];
      };
    };
}
