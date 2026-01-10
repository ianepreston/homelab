{
  description = "Just to run renovate";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      talosctlVersions = {

        "1.12.1" = {
          version = "1.11.3";
          sha256 = "sha256-fNOg0lqPLeo0PCgVQxzAfT6AurEk58PiJziBncCcGz8=";
        };
        "1.12.0" = {
          version = "1.12.0";
          sha256 = "sha256-EaJ0XPkrAWtHg6z161a/w5Su3mGpdt0Xtej20JOX4io=";
        };
      };
      # nix-prefetch-url https://github.com/siderolabs/talos/releases/download/v1.11.1/talosctl-linux-amd64
      # "1.12.0" = {
      #   version = "1.12.0";
      #   sha256 = "sha256-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=";
      # };
      selectedTalosctlVersion = "1.12.1"; # Change this to switch versions
      talosctlBinary =
        {
          pkgs,
          system,
          versionInfo,
        }:
        pkgs.stdenv.mkDerivation {
          pname = "talosctl";
          version = versionInfo.version;
          src = pkgs.fetchurl {
            url = "https://github.com/siderolabs/talos/releases/download/v${versionInfo.version}/talosctl-${
              if pkgs.stdenv.isDarwin then "darwin" else "linux"
            }-amd64";
            sha256 = versionInfo.sha256;
          };
          dontUnpack = true;
          installPhase = ''
            mkdir -p $out/bin
            cp $src $out/bin/talosctl
            chmod +x $out/bin/talosctl
          '';
        };

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            versionInfo = talosctlVersions.${selectedTalosctlVersion};
            talosctlPkg = talosctlBinary { inherit pkgs system versionInfo; };
            talhelperPkg = talhelper.packages.${system}.default;
          in
          f { inherit pkgs talosctlPkg talhelperPkg; }
        );
    in
    {
      devShells = forEachSupportedSystem (
        {
          pkgs,
          talhelperPkg,
          talosctlPkg,
        }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              ansible
              glibcLocales
              renovate
              envsubst
              terraform
              bws
              talosctlPkg
              talhelperPkg
              kubectl
              kubectl-cnpg
              kubernetes-helm
              helmfile
              kustomize
              clusterctl
              cilium-cli
              fluxcd
              minijinja
              bws
              bitwarden-cli
              go-task
              yq-go
              jq
            ];
            shellHook = ''
              #Cleanup any stale containers from previous runs
              CONTAINER_NAME="tfc-agent-homelab"
              ENV_FILE="./k8s.env"
              if [ -f "$ENV_FILE" ]; then
                set -a
                source "$ENV_FILE"
                set +a
              fi
              if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
                echo "🧹 Cleaning up existing TFC Agent..."
                docker stop $CONTAINER_NAME > /dev/null 2>&1
                docker rm $CONTAINER_NAME > /dev/null 2>&1
              fi
              #Start the agent in the background
              # --network host: Ensures the agent can reach local IPs (like Authentik)
              # --rm: Automatically remove container on stop
              docker run -d \
                --name $CONTAINER_NAME \
                --network host \
                -e TFC_AGENT_TOKEN="$TFC_AGENT_TOKEN" \
                -e TFC_AGENT_NAME="nix-$(hostname)" \
                hashicorp/tfc-agent:latest > /dev/null
            '';
          };
        }
      );
    };
}
