{
  description = "Home Manager configuration of wolfy";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations = {
        "alan" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
            {
              home = {
                username = "alan";
                homeDirectory = "/home/alan";
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
