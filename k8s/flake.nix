{
  description = "Setup env for working in my kubernetes clusters";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs =
    { self, nixpkgs }:
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
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShell {
            shellHook = ''
              cd ../../
              export TALOSCONFIG="$(pwd)/talos/dev/clusterconfig/talosconfig"
            '';
            packages = with pkgs; [
              talosctl
              kubectl
              kubernetes-helm
              kustomize
              clusterctl
              cilium-cli
              argocd
              fluxcd
              bws
              bitwarden-cli
              go-task
            ];
          };
        }
      );
    };
}
