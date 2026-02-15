# antigravity-nix

Auto-updating Nix Flake for Google Antigravity -- zero configuration, multi-platform, version-pinned.

[![Update Antigravity](https://github.com/jacopone/antigravity-nix/actions/workflows/update.yml/badge.svg)](https://github.com/jacopone/antigravity-nix/actions/workflows/update.yml)
[![Flake Check](https://img.shields.io/badge/flake-check%20passing-success)](https://github.com/jacopone/antigravity-nix)
[![NixOS](https://img.shields.io/badge/NixOS-ready-blue?logo=nixos)](https://nixos.org)

## What This Provides

- **FHS environment** wrapping the upstream binary with all required libraries
- **Automated updates** via GitHub Actions (3x/week), with hash verification and build testing
- **Multi-platform** support for x86_64-linux, aarch64-linux, x86_64-darwin, and aarch64-darwin
- **Version pinning** through tagged releases for reproducible builds

## Quick Start

```bash
nix run github:jacopone/antigravity-nix
```

## Installation

### NixOS Configuration

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, antigravity-nix, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            antigravity-nix.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, antigravity-nix, ... }: {
    homeConfigurations.your-user = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.packages = [
            antigravity-nix.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Overlay

```nix
{
  nixpkgs.overlays = [
    inputs.antigravity-nix.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    google-antigravity
  ];
}
```

## Usage

```bash
antigravity                  # launch from terminal
antigravity /path/to/project # open a specific project
```

## Version Pinning

```nix
# Follow latest (recommended)
inputs.antigravity-nix.url = "github:jacopone/antigravity-nix";

# Pin to a specific release
inputs.antigravity-nix.url = "github:jacopone/antigravity-nix/v1.11.2-6251250307170304";
```

Update to the latest version:

```bash
nix flake update antigravity-nix
```

All releases: https://github.com/jacopone/antigravity-nix/releases

## Requirements

- Nix with flakes enabled
- `allowUnfree = true` (Antigravity is proprietary software)
- On `aarch64-linux`, Chromium is used automatically since Google Chrome is unavailable

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with `nix build` and `nix flake check`
4. Submit a pull request

## License

MIT License -- see [LICENSE](LICENSE) for details.

Google Antigravity is proprietary software by Google LLC. This is an unofficial package, not affiliated with or endorsed by Google.
