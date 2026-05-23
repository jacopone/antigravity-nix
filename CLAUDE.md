# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**antigravity-nix** is an auto-updating Nix Flake that packages Google Antigravity (a proprietary agentic AI platform) for NixOS and Darwin systems. It uses API endpoints to detect new versions of the Base App, IDE, and CLI tools, automatically creating PRs with updates daily at 07:00 UTC.

**Key Challenge**: The Antigravity GUI distributions are binaries that require a standard Linux filesystem layout, which conflicts with NixOS's unique structure. This is solved using `buildFHSEnv` or `autoPatchelfHook` in a multi-component architecture.

## Architecture

### Component-Based Packaging

The flake now supports three discrete packages under the `pkgs/` directory:
1. `google-antigravity` (`pkgs/google-antigravity2.nix`): The default package, for the Antigravity 2.0 Base App.
2. `google-antigravity-ide` (`pkgs/google-antigravity-ide.nix`): The Antigravity IDE.
3. `google-antigravity-cli` (`pkgs/cli.nix`): The lightweight `agy` terminal CLI.

The GUI packages share the heavy-lifting extraction and FHS-wrapping logic via `pkgs/package.nix`.

### Chrome Integration Strategy

Antigravity GUI apps require Chrome to be available. The `package.nix` wrapper:
- Forces use of the user's existing Chrome profile (`~/.config/google-chrome`)
- Ensures any Chrome extensions the user has installed are available to Antigravity
- Sets `CHROME_BIN` and `CHROME_PATH` environment variables

### Version Detection Architecture

The update workflow uses API requests (via `curl` and `jq`) to Google Cloud Run endpoints to fetch the latest builds:

- `scripts/check-version.sh`: Quick API queries to determine if any component has an update
- `scripts/update-version.sh`: Full update process (version + hash verification via `nix-prefetch-url`)
- `artifacts/versions.json`: The source-of-truth JSON dictionary holding resolved URLs and SRI hashes for every component and platform

**Important**: Web scraping via Playwright has been completely removed in favor of direct API interaction.

## Common Commands

### Building and Testing

```bash
# Build the default package (Base App)
nix build .#default

# Test run without installing
nix run .#default

# Build and check flake
nix flake check

# Build the CLI
nix build .#google-antigravity-cli
```

### Version Management

```bash
# Enter the dev shell with necessary tools (jq, curl, gh)
nix develop

# Check for new version (no changes)
./scripts/check-version.sh

# Update to latest version (modifies versions.json, builds, commits)
./scripts/update-version.sh
```

### GitHub Workflows

**Manual triggers via `gh` CLI**:

```bash
# Manually trigger update workflow
gh workflow run update.yml

# View workflow runs
gh run list --workflow=update.yml
gh run view <run-id>
```

## Important Implementation Details

### Hash Updates

When updating versions in `artifacts/versions.json`, hashes must be converted to SRI format:

1. Download with `nix-prefetch-url` to get the base hash
2. Convert to SRI format with `nix hash to-sri`
3. Update `artifacts/versions.json` with the SRI hash (`sha256-...` or `sha512-...`)

**Never** use fake/placeholder hashes - the build will fail and CI won't catch it until runtime.

### FHS Environment Dependencies

The `targetPkgs` list in `pkgs/package.nix` includes all libraries the GUI apps need. If adding new dependencies:

- Include both the library and its transitive dependencies
- Add X11 libraries with `xorg.` prefix
- Include `stdenv.cc.cc.lib` for C++ standard library
- Test on a minimal NixOS system, not just your development machine

### Workflow Integration

The three workflows work together:

1. **update.yml**: Runs daily at 07:00 UTC, creates PRs, enables auto-merge
2. **release.yml**: Triggers on `artifacts/versions.json` changes to main, creates GitHub releases
3. **cleanup-branches.yml**: Deletes merged `auto-update/*` branches

**Release workflow** (release.yml) only runs when:
- `artifacts/versions.json` is modified
- Release tag doesn't already exist

## Testing Checklist

Before committing changes to packaging:

```bash
# 1. Verify build succeeds
nix build .#default --rebuild

# 2. Test the binary runs
./result/bin/antigravity --version

# 3. Verify flake metadata
nix flake metadata

# 4. Check for evaluation errors
nix flake check

# 5. Test CLI
nix run .#google-antigravity-cli -- --version
```

## Common Issues

### "Could not find Chrome" errors

The FHS wrapper sets `CHROME_BIN`/`CHROME_PATH` to a wrapper script, not the actual Chrome binary. If Antigravity can't find Chrome:

1. Verify `google-chrome` is in system packages
2. Check the wrapper script path in `pkgs/package.nix`
3. Test: `CHROME_BIN=/path/to/wrapper /path/to/wrapper --version`

### Workflow doesn't create PR

Check GitHub Actions logs. Common causes:

1. Version hasn't changed (intentional - exits cleanly)
2. Build failed (hash mismatch or missing dependencies)
3. Permissions issue (workflow needs `contents: write`)

## Updating This Package

### For New Antigravity Versions

The automated workflow handles this. To manually update:

```bash
./scripts/update-version.sh
# Reviews output, commits if successful
git push
```

### For Packaging Changes

When modifying `pkgs/*.nix` or `flake.nix`:

1. Test locally with multiple build approaches (FHS and no-FHS)
2. Verify the FHS environment includes all necessary libraries
3. Test with `nix run .#default` on a clean NixOS VM if possible
4. Check that the desktop entry works (`antigravity-ide` or `antigravity` command)

### For Workflow Changes

When modifying `.github/workflows/*.yml`:

1. Test with `gh workflow run <workflow>.yml`
2. Check workflow syntax: `gh workflow view <workflow>.yml`
3. Monitor with `gh run list --workflow=<workflow>.yml`
4. Validate secrets/permissions are correct
