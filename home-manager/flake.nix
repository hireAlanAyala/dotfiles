{
  description = "Home Manager configuration of wolfy";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, sops-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations = {
        "developer" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            sops-nix.homeManagerModules.sops
            ./home.nix
            {
              home = {
                username = "developer";
                homeDirectory = "/home/developer";
              };
            }
          ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
          # extraSpecialArgs = {
          #   inherit (nixpkgs) lib;
          #   inherit home-manager;
          # };
        };

        # I can add another user with different values here
        "wolfy" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            sops-nix.homeManagerModules.sops
            ./home.nix
            {
              home = {
                username = "wolfy";
                homeDirectory = "/home/wolfy";
              };
            }
          ];
        };

      };
    };
}
