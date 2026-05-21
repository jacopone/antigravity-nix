#!/usr/bin/env bash
# Quick version check script - shows current vs latest without updating

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Checking Antigravity versions..."
echo ""

check_app() {
    local name="$1"
    local path="$2"
    local url="$3"

    echo "--- $name ---"
    
    # Get current version
    local current
    current=$(grep -oP 'version = "\K[^"]+' "$path" | head -1)
    echo -e "Current version: $current"

    # Get latest version
    local latest
    if [[ "$name" == "CLI" ]]; then
        latest=$(curl -sL "$url" | jq -r '.url | match("antigravity-cli/([0-9.]+-[0-9]+)/").captures[0].string' 2>/dev/null || echo "")
    else
        latest=$(curl -sL "$url" | jq -r '.[0] | .version + "-" + .execution_id' 2>/dev/null || echo "")
    fi
    
    if [[ -n "$latest" && "$latest" != "null-null" ]]; then
        echo -e "Latest version:  $latest"
        
        if [[ "$current" == "$latest" ]]; then
            echo -e "${GREEN}✓ Already at latest version!${NC}"
        else
            echo -e "${YELLOW}⚠ Update available!${NC}"
        fi
    else
        echo -e "${RED}Error: Could not parse version from API${NC}"
    fi
    echo ""
}

check_app "Base" "pkgs/base/default.nix" "https://antigravity-auto-updater-974169037036.us-central1.run.app/releases"
check_app "CLI" "pkgs/cli/default.nix" "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json"
check_app "IDE" "pkgs/ide/default.nix" "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/releases"
