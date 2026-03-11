# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**antigravity-nix** is an auto-updating Nix Flake that packages Google Antigravity (a proprietary agentic IDE) for NixOS systems. It uses browser automation to detect new versions and automatically creates PRs with updates daily at 07:00 UTC.

**Key Challenge**: Antigravity is a binary distribution that requires a standard Linux filesystem layout, which conflicts with NixOS's unique structure. This is solved using `buildFHSEnv` to create an isolated FHS environment.

## Architecture

### Two-Stage Build Process

1. **antigravity-unwrapped** (package.nix:53-77): Extracts the upstream tarball into `/nix/store` without modification
2. **FHS Environment** (package.nix:80-135): Wraps the binary in a container with standard Linux paths and all required libraries

### Chrome Integration Strategy

Antigravity requires Chrome to be available. The package creates a Chrome wrapper (package.nix:44-50) that:
- Forces use of the user's existing Chrome profile (`~/.config/google-chrome`)
- Ensures any Chrome extensions the user has installed are available to Antigravity
- Sets `CHROME_BIN` and `CHROME_PATH` environment variables (package.nix:128-129)

### Version Detection Architecture

The update workflow uses **browser automation** (not curl) because Antigravity's download page is JavaScript-rendered:

- `scripts/scrape-version.js`: Playwright-based scraper that loads the page with a real browser
- `scripts/check-version.sh`: Quick version comparison (current vs. latest)
- `scripts/update-version.sh`: Full update process (version + hash + build test)

**Important**: The scraper requires `playwright-chromium` to be installed and browsers to be downloaded (`npx playwright install chromium`).

## Common Commands

### Building and Testing

```bash
# Build the package
nix build .#default

# Test run without installing
nix run .#default

# Build and check flake
nix flake check

# Update flake lock
nix flake update
```

### Version Management

```bash
# Check for new version (no changes)
./scripts/check-version.sh

# Update to latest version (modifies files, builds, commits)
./scripts/update-version.sh

# Manually test version scraping
node scripts/scrape-version.js
```

**Prerequisites for version scripts**:
- Node.js 20+
- `npm install -g playwright-chromium`
- `npx playwright install chromium`

### GitHub Workflows

**Manual triggers via `gh` CLI**:

```bash
# Manually trigger update workflow
gh workflow run update.yml

# Trigger with specific inputs
gh workflow run cleanup-branches.yml -f dry_run=true

# View workflow runs
gh run list --workflow=update.yml
gh run view <run-id>
```

## Important Implementation Details

### Hash Updates

When updating versions, the hash must be updated in two steps (scripts/update-version.sh:96-121):

1. Download with `nix-prefetch-url` to get base hash
2. Convert to SRI format with `nix hash to-sri`
3. Update `package.nix` with the SRI hash (`sha256-...`)

**Never** use fake/placeholder hashes - the build will fail and CI won't catch it until runtime.

### FHS Environment Dependencies

The `targetPkgs` list (package.nix:83-123) includes all libraries Antigravity needs. If adding new dependencies:

- Include both the library and its transitive dependencies
- Add X11 libraries with `xorg.` prefix
- Include `stdenv.cc.cc.lib` for C++ standard library
- Test on a minimal NixOS system, not just your development machine

### Workflow Integration

The three workflows work together:

1. **update.yml**: Runs daily at 07:00 UTC, creates PRs, enables auto-merge
2. **release.yml**: Triggers on `package.nix` changes to main, creates GitHub releases
3. **cleanup-branches.yml**: Deletes merged `auto-update/*` branches

**Release workflow** (release.yml) only runs when:
- `package.nix` is modified
- Version in `flake.nix` changed compared to previous commit
- Release tag doesn't already exist

### Version String Format

Antigravity uses the format: `MAJOR.MINOR.PATCH-BUILD_NUMBER`

Example: `1.11.2-6251250307170304`

This appears in three files:
- `flake.nix` line 58: metadata for consumers
- `package.nix` line 36: used in derivation
- Both must be updated together

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

# 5. Test on actual system (if modifying FHS env)
nix run .#default  # Launch full GUI
```

## Common Issues

### "Could not find Chrome" errors

The FHS wrapper sets `CHROME_BIN`/`CHROME_PATH` to a wrapper script, not the actual Chrome binary. If Antigravity can't find Chrome:

1. Verify `google-chrome` is in system packages
2. Check the wrapper script path in package.nix:44-50
3. Test: `CHROME_BIN=/path/to/wrapper /path/to/wrapper --version`

### Version scraping fails

The scraper requires JavaScript rendering. Common failures:

- **"playwright not found"**: Run `npm install -g playwright-chromium`
- **"executable not found"**: Run `npx playwright install chromium`
- **Timeout errors**: Increase timeout in scrape-version.js:23 (currently 30s)
- **No version found**: The page structure changed - update selectors in scrape-version.js:30-53

### Workflow doesn't create PR

Check GitHub Actions logs. Common causes:

1. Version hasn't changed (intentional - exits cleanly)
2. Playwright not installed (CI installs it, but check workflow output)
3. Build failed (hash mismatch or missing dependencies)
4. Permissions issue (workflow needs `contents: write`)

## Updating This Package

### For New Antigravity Versions

The automated workflow handles this. To manually update:

```bash
./scripts/update-version.sh
# Reviews output, commits if successful
git push
```

### For Packaging Changes

When modifying `package.nix` or `flake.nix`:

1. Test locally with multiple build approaches
2. Verify the FHS environment includes all necessary libraries
3. Test with `nix run .#default` on a clean NixOS VM if possible
4. Check that the desktop entry works (`antigravity` command from launcher)

### For Workflow Changes

When modifying `.github/workflows/*.yml`:

1. Test with `gh workflow run <workflow>.yml`
2. Check workflow syntax: `gh workflow view <workflow>.yml`
3. Monitor with `gh run list --workflow=<workflow>.yml`
4. Validate secrets/permissions are correct
