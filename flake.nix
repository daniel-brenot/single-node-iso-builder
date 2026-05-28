{
  description = "Build burnable NixOS live ISOs for a single-node k3s host.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    auto-updater-amd64 = {
      url = "file+https://github.com/daniel-brenot/auto-updater/releases/download/latest/auto-updater-linux-amd64";
      flake = false;
    };

    auto-updater-aarch64 = {
      url = "file+https://github.com/daniel-brenot/auto-updater/releases/download/latest/auto-updater-linux-aarch64";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      auto-updater-amd64,
      auto-updater-aarch64,
      ...
    }:
    let
      lib = nixpkgs.lib;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = lib.genAttrs supportedSystems;

      mkIsoSystem =
        system:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            autoUpdaterBinary =
              {
                x86_64-linux = auto-updater-amd64;
                aarch64-linux = auto-updater-aarch64;
              }
              .${system};
          };
          modules = [
            ./nixos/iso.nix
            {
              nixpkgs.hostPlatform = system;
              system.stateVersion = "25.11";
            }
          ];
        };

      isoSystems = forAllSystems mkIsoSystem;
    in
    {
      nixosConfigurations = {
        single-node-k3s-x86_64 = isoSystems.x86_64-linux;
        single-node-k3s-aarch64 = isoSystems.aarch64-linux;
      };

      packages = forAllSystems (
        system:
        let
          isoImage = isoSystems.${system}.config.system.build.isoImage;
        in
        {
          default = isoImage;
          iso = isoImage;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
