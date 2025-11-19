#!/usr/bin/env bash
# Auto-update script for Google Antigravity

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Function to extract version from download page
get_latest_version() {
    log_info "Fetching latest version from antigravity.google..."

    # Fetch the download page
    local download_page
    download_page=$(curl -sL --compressed "https://antigravity.google/download/linux" 2>/dev/null || echo "")

    # Check if download page was fetched successfully
    if [[ -z "$download_page" ]]; then
        log_error "Failed to fetch download page from antigravity.google"
        log_warn "Keeping current version (network issue or page unavailable)"
        return 1
    fi

    # Extract version from the download URL
    # The URL pattern is: https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/VERSION/linux-x64/Antigravity.tar.gz
    local version
    version=$(echo "$download_page" | tr -d '\000' | grep -oP 'antigravity/stable/\K[0-9.]+-[0-9]+' | head -1)

    if [[ -z "$version" ]]; then
        log_error "Could not extract version from download page"
        log_warn "Page format may have changed. Manual investigation needed."
        return 1
    fi

    echo "$version"
}

# Function to get current version from flake
get_current_version() {
    grep -oP 'version = "\K[^"]+' flake.nix | head -1
}

# Function to update version in files
update_version() {
    local new_version="$1"

    log_info "Updating version to $new_version..."

    # Update flake.nix
    sed -i "s/version = \".*\"/version = \"$new_version\"/" flake.nix

    # Update package.nix
    sed -i "s/version = \".*\"/version = \"$new_version\"/" package.nix

    log_info "Version updated in flake.nix and package.nix"
}

# Function to update hash
update_hash() {
    local new_version="$1"
    local url="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${new_version}/linux-x64/Antigravity.tar.gz"

    log_info "Fetching hash for new version..."

    # Use nix-prefetch-url to get the correct hash
    local hash
    hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)

    if [[ -z "$hash" ]]; then
        log_error "Could not fetch hash for new version"
        return 1
    fi

    # Convert to SRI hash format
    local sri_hash
    sri_hash=$(nix hash to-sri --type sha256 "$hash")

    log_info "New hash: $sri_hash"

    # Update package.nix with new hash
    sed -i "s|sha256 = \"sha256-.*\"|sha256 = \"$sri_hash\"|" package.nix

    log_info "Hash updated in package.nix"
}

# Function to test build
test_build() {
    log_info "Testing build..."

    if nix build .#default --no-link; then
        log_info "Build test successful!"
        return 0
    else
        log_error "Build test failed!"
        return 1
    fi
}

# Main script
main() {
    cd "$(dirname "$0")/.."

    log_info "Starting Google Antigravity update check..."

    # Get current version
    local current_version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"

    # Get latest version
    local latest_version
    latest_version=$(get_latest_version)
    log_info "Latest version: $latest_version"

    # Check if update is needed
    if [[ "$current_version" == "$latest_version" ]]; then
        log_info "Already at latest version. No update needed."
        exit 0
    fi

    log_warn "New version available: $latest_version"

    # Update version
    update_version "$latest_version"

    # Update hash
    update_hash "$latest_version"

    # Test build
    if ! test_build; then
        log_error "Build failed after update. Please check manually."
        exit 1
    fi

    log_info "Update complete! Version updated from $current_version to $latest_version"

    # Optionally commit changes
    if command -v git &> /dev/null && [[ -d .git ]]; then
        log_info "Committing changes..."
        git add flake.nix package.nix
        git commit -m "chore: update Google Antigravity to version $latest_version"
        log_info "Changes committed. Don't forget to push!"
    fi
}

main "$@"
