{
  description = "dotfiles";

  inputs = {
    # Use `github:NixOS/nixpkgs/nixpkgs-26.05-darwin` to use Nixpkgs 26.05.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Use `github:nix-darwin/nix-darwin/nix-darwin-26.05` to use Nixpkgs 26.05.
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-linux.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager-linux.url = "github:nix-community/home-manager/release-26.05";
    home-manager-linux.inputs.nixpkgs.follows = "nixpkgs-linux";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nix-homebrew, home-manager, home-manager-linux, nixpkgs-linux, ... }:
    let 
	user = "xji";
      mkLinuxHome = system: module: home-manager-linux.lib.homeManagerConfiguration {
        pkgs = nixpkgs-linux.legacyPackages.${system};
        extraSpecialArgs = {
          user = builtins.getEnv "USER";
          homeDirectory = builtins.getEnv "HOME";
        };
        modules = [ module ];
      };
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
         specialArgs = { inherit user; }; 
	 modules = [
           ./mac/configuration.nix
           nix-homebrew.darwinModules.nix-homebrew
	   {
	     nix-homebrew = {
		enable = true;
 		autoMigrate = true;
	    };
	  } 

           home-manager.darwinModules.home-manager
           {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user; };
	    home-manager.backupFileExtension = "backup";
            home-manager.users.${user} = import ./mac/home.nix;
           }
      ];
    };
      homeConfigurations = {
        "wsl-x86_64" = mkLinuxHome "x86_64-linux" ./wsl/home.nix;
        "wsl-aarch64" = mkLinuxHome "aarch64-linux" ./wsl/home.nix;
        "server-x86_64" = mkLinuxHome "x86_64-linux" ./server/home.nix;
        "server-aarch64" = mkLinuxHome "aarch64-linux" ./server/home.nix;
      };
  };
}
