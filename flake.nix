{
  description = "Yanzi - Komi's NixOS Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
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
    nixosConfigurations.Niko = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit self inputs system;};
      modules = [
        nvf.nixosModules.default

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
