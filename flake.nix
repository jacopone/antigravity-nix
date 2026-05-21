{
  description = "Google Antigravity - Next-generation agentic IDE (Nix package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };
      in
      {
        packages = {
          inherit (pkgs)
            google-antigravity2
            google-antigravity2-no-fhs
            google-antigravity-ide
            google-antigravity-ide-no-fhs
            google-antigravity-cli
            ;
          default = pkgs.google-antigravity-ide;
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
            echo "  node scripts/antigravity-2-and-ide--1--scrape-download-page.mjs"
            echo "  node scripts/antigravity-cli--parse-install-script-and-download-manifests.mjs"
            echo "  node scripts/antigravity-2-and-ide--2--prefetch-links.mjs"
            echo "  node scripts/update-version.mjs"
            echo "  node scripts/test.mjs"
            echo ""
            echo "First time setup:"
            echo "  npm install  - Install playwright-chromium locally"
            echo ""
            echo "Note: Requires google-chrome-stable to be installed system-wide for browser automation"
          '';
        };
      }
    )
    // {
      # Overlay for easy integration into NixOS configurations
      overlays.default = final: _prev: {
        google-antigravity2 = final.callPackage ./google-antigravity2.nix { };
        google-antigravity2-no-fhs = final.callPackage ./google-antigravity2.nix { useFHS = false; };
        google-antigravity-ide = final.callPackage ./google-antigravity-ide.nix { };
        google-antigravity-ide-no-fhs = final.callPackage ./google-antigravity-ide.nix { useFHS = false; };
        google-antigravity-cli = final.callPackage ./cli.nix { };
      };
    };
}
