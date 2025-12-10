{
  description = "Google Antigravity - Next-generation agentic IDE (Nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        packages = {
          default = pkgs.callPackage ./package.nix { };
          google-antigravity = pkgs.callPackage ./package.nix { };
        };

        apps = {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/antigravity";
          };
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
            echo "First time setup:"
            echo "  npm install  - Install playwright-chromium locally"
            echo ""
            echo "Note: Requires google-chrome-stable to be installed system-wide for browser automation"
          '';
        };
      }
    ) // {
      # Version information for auto-update
      version = "1.11.17-6639170008514560";

      # Overlay for easy integration into NixOS configurations
      overlays.default = final: prev: {
        google-antigravity = final.callPackage ./package.nix { };
      };
    };
}
