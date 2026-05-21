{
  description = "Google Antigravity - Next-generation agentic IDE (Nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        packages = {
          default = pkgs.callPackage ./pkgs/ide/default.nix {};
          google-antigravity = pkgs.callPackage ./pkgs/base/default.nix {};
          google-antigravity-no-fhs = pkgs.callPackage ./pkgs/base/default.nix {useFHS = false;};
          google-antigravity-ide = pkgs.callPackage ./pkgs/ide/default.nix {};
          google-antigravity-ide-no-fhs = pkgs.callPackage ./pkgs/ide/default.nix {useFHS = false;};
          google-antigravity-cli = pkgs.callPackage ./pkgs/cli/default.nix {};
        };

        # Development shell for working on this flake
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nix
            git
            curl
            jq
            gh
            nodejs_20
          ];

          shellHook = ''
            echo "Antigravity development environment"
            echo "Available commands:"
            echo "  ./scripts/check-version.sh  - Check current vs latest version"
            echo "  ./scripts/update-version.sh - Update to latest version"
            echo ""
            echo "Note: Requires google-chrome-stable to be installed system-wide for browser-based apps"
          '';
        };
      }
    )
    // {
      # Overlay for easy integration into NixOS configurations
      overlays.default = final: prev: {
        google-antigravity = final.callPackage ./pkgs/base/default.nix {};
        google-antigravity-no-fhs = final.callPackage ./pkgs/base/default.nix {useFHS = false;};
        google-antigravity-ide = final.callPackage ./pkgs/ide/default.nix {};
        google-antigravity-ide-no-fhs = final.callPackage ./pkgs/ide/default.nix {useFHS = false;};
        google-antigravity-cli = final.callPackage ./pkgs/cli/default.nix {};
      };
    };
}
