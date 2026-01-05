{
  description = "Home Manager configuration of walker";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # sops-nix = {
    #   url = "github:Mic92/sops-nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations = {
        "walker" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            # sops-nix.homeManagerModules.sops
            ./home.nix
            {
              home = {
                username = "walker";
                homeDirectory = "/home/walker";
              };
            }
          ];
        };
      };
    };
}
