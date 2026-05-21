#!/usr/bin/env bash
# Auto-update script for Google Antigravity apps

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

update_app() {
    local name="$1"
    local path="$2"
    local url="$3"
    local dl_url_template="$4"
    local flake_attr="$5"

    log_info "Checking updates for $name..."

    # Get current version
    local current_version
    current_version=$(grep -oP 'version = "\K[^"]+' "$path" | head -1)

    # Get latest version
    local latest_version
    if [[ "$name" == "CLI" ]]; then
        latest_version=$(curl -sL "$url" | jq -r '.url | match("antigravity-cli/([0-9.]+-[0-9]+)/").captures[0].string' 2>/dev/null || echo "")
    else
        latest_version=$(curl -sL "$url" | jq -r '.[0] | .version + "-" + .execution_id' 2>/dev/null || echo "")
    fi

    if [[ -z "$latest_version" || "$latest_version" == "null-null" ]]; then
        log_error "Could not extract latest version for $name"
        return 1
    fi

    if [[ "$current_version" == "$latest_version" ]]; then
        log_info "$name is already at latest version ($current_version)"
        return 0
    fi

    log_warn "Updating $name from $current_version to $latest_version"

    # Replace version
    sed -i "s/version = \".*\"/version = \"$latest_version\"/" "$path"

    # Fetch new hash
    local dl_url="${dl_url_template//VERSION/$latest_version}"
    log_info "Fetching new hash from $dl_url"
    
    local extra_args=""
    if [[ "$name" == "IDE" ]]; then
        extra_args="--name Antigravity_IDE.tar.gz"
    fi

    local hash
    # shellcheck disable=SC2086
    hash=$(nix-prefetch-url --type sha256 $extra_args "$dl_url" 2>/dev/null || echo "")

    if [[ -z "$hash" ]]; then
        log_error "Failed to fetch hash for $name"
        # Revert version if hash fails
        sed -i "s/version = \"$latest_version\"/version = \"$current_version\"/" "$path"
        return 1
    fi

    local sri_hash
    sri_hash=$(nix hash to-sri --type sha256 "$hash")
    log_info "New hash: $sri_hash"

    sed -i "s|sha256 = \".*\"|sha256 = \"$sri_hash\"|" "$path"

    log_info "Testing build for $name..."
    if ! nix build .#"$flake_attr" --no-link; then
        log_error "Build failed for $name. Please check manually."
        return 1
    fi
    log_info "$name updated successfully!"
}

main() {
    cd "$(dirname "$0")/.."

    local has_errors=0

    update_app "Base" "pkgs/base/default.nix" "https://antigravity-auto-updater-974169037036.us-central1.run.app/releases" "https://storage.googleapis.com/antigravity-public/antigravity-hub/VERSION/linux-x64/Antigravity.tar.gz" "google-antigravity" || has_errors=1
    
    update_app "CLI" "pkgs/cli/default.nix" "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json" "https://storage.googleapis.com/antigravity-public/antigravity-cli/VERSION/linux-x64/cli_linux_x64.tar.gz" "google-antigravity-cli" || has_errors=1
    
    update_app "IDE" "pkgs/ide/default.nix" "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/releases" "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/VERSION/linux-x64/Antigravity%20IDE.tar.gz" "google-antigravity-ide" || has_errors=1

    if [[ $has_errors -eq 0 ]]; then
        log_info "All updates processed successfully."
        if command -v git &> /dev/null && [[ -d .git ]]; then
            log_info "Committing changes..."
            git add flake.nix pkgs/
            git commit -m "chore: auto-update Antigravity packages" || true
        fi
    else
        log_error "Some updates failed. Check logs above."
        exit 1
    fi
}

main "$@"
