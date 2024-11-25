{
  description = "Configure Talos for my prod cluster";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";

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
        f: nixpkgs.lib.genAttrs supportedSystems (system: f { pkgs = import nixpkgs { inherit system; }; });
    in
    {
      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShell {
            shellHook = ''
              export TALOSENV="prod"
              # export TALOSCONFIG="$(pwd)/rendered/talosconfig"
              # talosctl config endpoints 192.168.40.7 192.168.40.9 192.168.40.11
            '';
          };
        }
      );
    };
}
