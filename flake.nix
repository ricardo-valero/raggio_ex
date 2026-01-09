{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = {nixpkgs, ...}: let
    systems = nixpkgs.lib.systems.flakeExposed;
  in {
    devShells = nixpkgs.lib.genAttrs systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      beam-pkgs = pkgs.beam.packages.erlang_26;
    in {
      default = pkgs.mkShell {
        packages = builtins.attrValues {
          inherit (pkgs) git nixd alejandra;
          inherit (beam-pkgs) elixir;
        };
      };
    });
  };
}
