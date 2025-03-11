{
  description = "Setup env for working in my kubernetes clusters";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    talhelper.url = "github:budimanjojo/talhelper";
  };

  outputs =
    {
      self,
      nixpkgs,
      talhelper,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            talhelperPkg = talhelper.packages.${system}.default;
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs, talhelperPkg }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              talosctl
              talhelperPkg
              kubectl
              kubernetes-helm
              clusterctl
              argocd
              cilium-cli
              #bitwarden-secrets
              bws
              bitwarden-cli
            ];
          };
        }
      );
    };
}
