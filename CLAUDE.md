# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**antigravity-nix** is an auto-updating Nix Flake that packages Google Antigravity (a proprietary agentic IDE) for NixOS systems. It uses browser automation to detect new versions and automatically creates PRs with updates daily at 07:00 UTC.

## Architecture

### Dynamic JSON Manifest Loading

Nix files in this repository do not contain any hardcoded versions, download URLs, or hashes. All information is loaded dynamically at evaluation time from declarative JSON manifests:
1. **Desktop Applications**:
   - `artifacts/antigravity-2-and-ide--1--scraped-links.json`: Contains direct scraped download URLs for all OS and architecture targets of Antigravity 2.0 and Antigravity IDE.
   - `artifacts/antigravity-2-and-ide--2--prefetched-sha256.json`: Contains the SHA-256 base64 (SRI) hashes of all prefetched binaries.
2. **CLI (agy)**:
   - `artifacts/antigravity-cli--manifests/*.json`: Contains scraped manifest files mapping platform systems (e.g. `linux_amd64.json`) to their version, download URL, and hex SHA-512 hashes.

### Reusable Package Builder

- `./package.nix`: Reusable package builder which takes `appType` (either `"Antigravity 2.0"` or `"Antigravity IDE"`), loads the download links and hashes, identifies the target architecture, extracts the build version from the URL path, packages the application for FHS and non-FHS systems (Linux) or copies it to `Applications/` (macOS Darwin), and handles app-specific folder locations and icons conditionally.
- `./google-antigravity2.nix` & `./google-antigravity-ide.nix`: Minimal entrypoints that call `./package.nix` passing `"Antigravity 2.0"` and `"Antigravity IDE"` respectively.
- `./cli.nix`: Packages the Google Antigravity CLI dynamically from the scraped JSON manifests based on target platform.

### Multi-Stage JavaScript Version Detection

Version updates are fully implemented in platform-independent JavaScript:
- **Stage 01 (Scrape)**:
  - `node scripts/antigravity-2-and-ide--1--scrape-download-page.mjs`: Playwright-based scraper that extracts desktop links from `https://antigravity.google/download` and outputs `artifacts/antigravity-2-and-ide--1--scraped-links.json`.
  - `node scripts/antigravity-cli--parse-install-script-and-download-manifests.mjs`: Parses the CLI installer script and fetches target manifest files into `./artifacts/antigravity-cli--manifests/`.
- **Stage 02 (Prefetch & Hash)**:
  - `node scripts/antigravity-2-and-ide--2--prefetch-links.mjs`: Downloads the scraped desktop tarballs and DMGs, computes their base64 SHA-256 hashes in SRI format, and writes them to `artifacts/antigravity-2-and-ide--2--prefetched-sha256.json`.
- **Orchestration**:
  - `node scripts/update-version.mjs`: Performs the full update cycle (scrapes links and CLI manifests, prefetches/hashes desktop packages, runs Nix test builds on all targets, and commits the updates to Git).

## Common Commands

### Building and Testing

```bash
# Build Google Antigravity IDE (Default)
nix build .#google-antigravity-ide --no-link

# Build Google Antigravity 2.0 App
nix build .#google-antigravity2 --no-link

# Build Google Antigravity CLI (agy)
nix build .#google-antigravity-cli --no-link

# Run parallel integration tests
node scripts/test.mjs

# Run flake validation check
nix flake check
```

### Version Management

```bash
# Perform full automated update (scrapes, pre-fetches hashes, tests builds, commits)
node scripts/update-version.mjs
```

**Prerequisites for scraping**:
- Run `npm install` inside the repository to install playwright-chromium.
- Requires `google-chrome-stable` system-wide for browser automation (Playwright will reuse your system binary).

## Important Implementation Details

### deduped Overlay Pattern

Flake outputs are cleanly unified via a DRY (Don't Repeat Yourself) overlay. Packages for each architecture are projected directly from `self.overlays.default` applied to `nixpkgs`, avoiding duplicated declarations:
```nix
overlays.default = final: prev: {
  google-antigravity2 = final.callPackage ./google-antigravity2.nix {};
  google-antigravity2-no-fhs = final.callPackage ./google-antigravity2.nix {useFHS = false;};
  google-antigravity-ide = final.callPackage ./google-antigravity-ide.nix {};
  google-antigravity-ide-no-fhs = final.callPackage ./google-antigravity-ide.nix {useFHS = false;};
  google-antigravity-cli = final.callPackage ./cli.nix {};
};
```
