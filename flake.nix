{
  description = "Everything, everywhere, all at once";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    hardware.url = "github:NixOS/nixos-hardware";
    hardware-fork.url = "github:noisesfromspace/nixos-hardware";

    nixos-raspberrypi = {
      # https://github.com/nvmd/nixos-raspberrypi/pull/131
      url = "github:nvmd/nixos-raspberrypi?ref=pull/131/head";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/DeterminateSystems/nix-src/releases
    determinate.url = "github:DeterminateSystems/nix-src/v3.16.0";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      # https://github.com/nix-community/lanzaboote/releases
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-bitcoin = {
      url = "github:fort-nix/nix-bitcoin/master";
    };

    nix-mineral = {
      url = "github:cynicsketch/nix-mineral";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zmx.url = "github:neurosnap/zmx/";
    llm-agents.url = "github:numtide/llm-agents.nix";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+file:///etc/nixos/secrets";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-raspberrypi,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;

      importSystem =
        name:
        {
          system,
          modules ? [ ],
          call ? lib.nixosSystem,
        }:
        let
          systemconfig = ./hosts/${name}/default.nix;
          hardwareconfig = ./hosts/${name}/hardware.nix;
          homeconfig = ./hosts/${name}/home.nix;
        in
        call {
          inherit system;
          specialArgs = { inherit inputs nixos-raspberrypi; };
          modules =
            with inputs;
            [
              systemconfig
              hardwareconfig
              ./nixos/system.nix

              {
                home-manager = {
                  useGlobalPkgs = true;
                  users.martijn = import homeconfig;
                  extraSpecialArgs = { inherit inputs system; };
                };
                nixpkgs = {
                  config.allowUnfree = true;
                  overlays = [
                    outputs.overlays
                    (final: prev: {
                      # stable packages through pkgs.stable.gimp
                      stable = import inputs.nixpkgs-stable {
                        system = final.stdenv.hostPlatform.system;
                        config.allowUnfree = true;
                      };
                    })
                    # bring in custom package on pkgs.custom-package
                    (final: prev: import ./pkgs { pkgs = final; })
                  ];
                };
              }

              agenix.nixosModules.default # secrets
              home-manager.nixosModules.home-manager
              lanzaboote.nixosModules.lanzaboote # secureboot
              nix-mineral.nixosModules.nix-mineral # schizo settings

              {
                options.global = with lib; {
                  wan_ips = mkOption {
                    type = with types; attrsOf str;
                    default = {
                      rekkaken = "46.62.135.158";
                      rekkaken_6 = "2a01:4f9:c013:98b::1";
                      shoryuken = "157.180.79.166";
                      shoryuken_6 = "2a01:4f9:c013:c5fa::1";
                    };
                  };
                  tailscale_hosts = mkOption {
                    type = with types; attrsOf str;
                    default = {
                      donk = "100.64.0.8";
                      dosukoi = "100.64.0.9";
                      hadouken = "100.64.0.20";
                      nurma = "100.64.0.3";
                      pikvm = "100.64.0.5";
                      pixel = "100.64.0.6";
                      rekkaken = "100.64.0.1";
                      shoryuken = "100.64.0.18";
                      suzaku = "100.64.0.7";
                      tatsumaki = "100.64.0.2";
                      tenshin = "100.64.0.4";
                    };
                  };
                };
              }

            ]
            ++ modules;
        };
    in
    {
      # prev = unaltered (before overlays)
      # final = after overlay mods, like rec keyword
      overlays = final: prev: {
        # strawberry = prev.strawberry.overrideAttrs (oldAttrs: {
        #   dontStrip = true;
        #   dontPatchELF = true;
        #   cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [ "-DCMAKE_BUILD_TYPE=Debug" ];
        # });
      };

      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # ------------ Cloud ------------
      nixosConfigurations.shoryuken = importSystem "shoryuken" {
        system = "x86_64-linux";
        modules = [ inputs.disko.nixosModules.disko ];
      };
      nixosConfigurations.rekkaken = importSystem "rekkaken" {
        system = "x86_64-linux";
        modules = [ inputs.disko.nixosModules.disko ];
      };

      # ------------ Servers ------------
      nixosConfigurations.tenshin = importSystem "tenshin" {
        system = "aarch64-linux";
        call = inputs.nixos-raspberrypi.lib.nixosSystem;
        modules = with inputs.nixos-raspberrypi.nixosModules; [
          raspberry-pi-4.base
          inputs.disko.nixosModules.disko
        ];
      };
      nixosConfigurations.suzaku = importSystem "suzaku" {
        system = "aarch64-linux";
        call = inputs.nixos-raspberrypi.lib.nixosSystem;
        modules = with inputs.nixos-raspberrypi.nixosModules; [
          raspberry-pi-5.base
          inputs.disko.nixosModules.disko
        ];
      };
      nixosConfigurations.hadouken = importSystem "hadouken" {
        system = "x86_64-linux";
      };
      nixosConfigurations.dosukoi = importSystem "dosukoi" {
        system = "x86_64-linux";
        modules = [ inputs.disko.nixosModules.disko ];
      };
      nixosConfigurations.tatsumaki = importSystem "tatsumaki" {
        system = "x86_64-linux";
        modules = [
          inputs.disko.nixosModules.disko
          inputs.nix-bitcoin.nixosModules.default
        ];
      };

      # -------------- PCs --------------
      nixosConfigurations.nurma = importSystem "nurma" {
        system = "x86_64-linux";
      };
      nixosConfigurations.paddy = importSystem "paddy" {
        system = "x86_64-linux";
        modules = [ inputs.hardware-fork.nixosModules.dell-da14250 ];
      };
      nixosConfigurations.donk = importSystem "donk" {
        system = "x86_64-linux";
        modules = [ inputs.hardware.nixosModules.framework-12-13th-gen-intel ];
      };
    };
}
