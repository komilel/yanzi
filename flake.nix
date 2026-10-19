{
  description = "Yanzi - Komi's NixOS Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Generation 529's known-good firmware; keep other packages on current nixpkgs.
    nixpkgs-firmware.url = "github:nixos/nixpkgs/ec2d622de0773551768cf98f3fc50cbcc003b9c5";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    oglgl.url = "github:wntkys/oglgl";

    shluz = {
      url = "git+https://fjo.osds.digital/forgejo-admin/shluz-bin.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nvf,
    sops-nix,
    ...
  } @ inputs: let
    system = "x86_64-linux";
  in {
    packages.${system} = {
      fingerprint-ocv = nixpkgs.legacyPackages.${system}.callPackage ./modules/fingerprint/package.nix {};
      weylus-pipewire = nixpkgs.legacyPackages.${system}.callPackage ./modules/weylus {};
    };

    checks.${system} = {
      weylus-pipewire =
        nixpkgs.legacyPackages.${system}.runCommand "weylus-pipewire-regressions" {
          nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [nodejs bash coreutils];
        } ''
          export CLIENT_JS=${self.packages.${system}.weylus-pipewire.patchedWeylus}/share/weylus/lib.js
          node ${./modules/weylus/tests/client.cjs}
          node ${./modules/weylus/tests/launcher.cjs} ${./modules/weylus/launch.sh}
          touch "$out"
        '';

      fingerprint-pam = nixpkgs.legacyPackages.${system}.callPackage ./modules/fingerprint/tests/pam-order.nix {
        inherit (self.nixosConfigurations.Niko.config.security.pam) services;
      };
    };

    nixosConfigurations.Niko = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit self inputs system;};
      modules = [
        nvf.nixosModules.default
        inputs.shluz.nixosModules.default

        sops-nix.nixosModules.sops

        ./hosts/niko

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {inherit inputs system;};
          home-manager.users.komi = ./home/home.nix;
        }
      ];
    };
  };
}
