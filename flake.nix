{
  description = "A tmux-sessionizer inspired script using sway.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = rec {
          swayssionizer =
            pkgs.writeShellApplication {
              name = "swayssionizer";
              runtimeInputs = with pkgs; [
                kitty
                tofi
                libnotify
              ];
              text = (builtins.readFile ./swayssionizer.sh);
            };
          default = swayssionizer;
        };
      }
    );
}
