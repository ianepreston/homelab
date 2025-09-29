{
  description = "Setup env for working in my kubernetes clusters";

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
        "1.9.0" = {
          version = "1.9.0";
          sha256 = "0ny2ilrkqy3k5x8d103cr3ipgndqab62yws01wgr4rw0903bsvm0";
        };
        "1.9.1" = {
          version = "1.9.1";
          sha256 = "0mf5z5f2ag7954a7wgzwk7id9vssqhdkq5356h50inwlhdhqdg1x";
        };
        "1.9.2" = {
          version = "1.9.2";
          sha256 = "120mbxxrc57cg92gvcrcqwinqms9b5g2nss47f0hv6gzsqxx6ypq";
        };
        "1.9.3" = {
          version = "1.9.3";
          sha256 = "0vp2pmlx1ay2dsckhsq4cwy7cx8f98sjgwkh3wkzifkchm7rzrj1";
        };
        "1.9.4" = {
          version = "1.9.4";
          sha256 = "1knxdahl6bx6sc3chdim14zj2nyyjj2pm0b78bspsxjq7irxm87v";
        };
        "1.9.5" = {
          version = "1.9.5";
          sha256 = "sha256-CFsInf0sKNvpSJ/yGKvR9upK2FIMNLFi0Hm6W0XM2mI=";
        };
        "1.9.6" = {
          version = "1.9.6";
          sha256 = "0jmb2k0a56gpqwg17d8myl35q4vy7zcnz9m0h1jjrr5zs6n4nzqw";
        };
        "1.10.0" = {
          version = "1.10.0";
          sha256 = "sha256-ZijtXX7dS7ZILknutcRTMweIhBDC9VnU5xIUF01CV0Q=";
        };
        "1.10.7" = {
          version = "1.10.7";
          sha256 = "1b59q9hbyjyy16x7msrjkycqv8hnwyqlnqmgniimi4mfnw3s5s0g";
        };
        "1.11.0" = {
          version = "1.11.0";
          sha256 = "sha256-JV6g2h34ycFfzp+n9P8PDWoY353hAKdrJKAw2lGukqI=";
        };
        "1.11.1" = {
          version = "1.11.1";
          sha256 = "sha256-nZadAFCHzAcguEeGFQSZ/36zsGAXpSP92NGh0lFA6zo=";
        };
        "1.11.2" = {

          version = "1.11.2";
          sha256 = "sha256-2FiuKD8rbhUwtScNhgqAaUxOwPYpm4Oiqvd5Xloci0k=";
        };

        # nix-prefetch-url https://github.com/siderolabs/talos/releases/download/v1.11.1/talosctl-linux-amd64
        # "1.11.1" = {
        #   version = "1.11.1";
        #   sha256 = "sha256-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=";
        # };
      };

      selectedTalosctlVersion = "1.11.2"; # Change this to switch versions
      # Just grab the binary, figuring out reproducible builds for the whole toolchain sucks
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
              talosctlPkg
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
