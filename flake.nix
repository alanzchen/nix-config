{
  description = "Alan's multi-host Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-src = {
      url = "github:Homebrew/brew/7.0.3";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-osxphotos = {
      url = "github:RhetTbull/homebrew-osxphotos";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      ...
    }:
    let
      mkDarwinHost = import ./lib/mk-darwin-host.nix { inherit inputs; };

      darwinConfigurations = {
        personal-new = let
          identity = builtins.fromJSON (builtins.readFile ./hosts/personal-new/identity.json);
        in mkDarwinHost {
          name = "personal-new";
          hostName = identity.hostName;
          username = identity.username;
          modules = [ ./hosts/personal-new/configuration.nix ];
          homeModule = ./home/alan.nix;
          enableNixHomebrew = true;
        };

        alans-macbook-air-1 = mkDarwinHost {
          name = "alans-macbook-air-1";
          modules = [
            ./hosts/alans-macbook-air-1/configuration.nix
          ]
          ++ import ./profiles/darwin/personal.nix;
          homeModule = ./home/alan.nix;
          enableNixHomebrew = true;
        };

        work-mbp = mkDarwinHost {
          name = "work-mbp";
          hostName = "UTD98207";
          modules = [
            ./hosts/work-mbp/configuration.nix
            ./profiles/darwin/work.nix
          ];
          manageUserShell = false;
          enableTouchIdSudo = false;
        };

        work-studio = mkDarwinHost {
          name = "work-studio";
          hostName = "alan-mac-studio";
          modules = [
            ./hosts/work-studio/configuration.nix
            ./profiles/darwin/work.nix
          ];
          manageUserShell = false;
          enableTouchIdSudo = false;
        };
      };

      oracleHome = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          username = "ubuntu";
          homeDirectory = "/home/ubuntu";
          hostName = "oracle";
        };
        modules = [ ./home/minimal.nix ];
      };

      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      inherit darwinConfigurations;

      packages.aarch64-darwin.credential-python =
        darwinConfigurations.personal-new.pkgs.python3.withPackages (ps: [ ps.cryptography ps.bcrypt ]);

      homeConfigurations."ubuntu@oracle" = oracleHome;

      checks = {
        aarch64-darwin = {
          personal-new = darwinConfigurations.personal-new.system;
          personal-air = darwinConfigurations.alans-macbook-air-1.system;
          work-mbp = darwinConfigurations.work-mbp.system;
          work-studio = darwinConfigurations.work-studio.system;
        };
        aarch64-linux.oracle-home = oracleHome.activationPackage;
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
