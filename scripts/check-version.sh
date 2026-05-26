#!/usr/bin/env nix-shell
#!nix-shell -i bash -p jq curl

set -euo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "Checking Antigravity versions..."
echo ""

VERSIONS_JSON="artifacts/versions.json"

if [[ ! -f "$VERSIONS_JSON" ]]; then
    echo -e "${RED}Error: $VERSIONS_JSON not found. Run update-version.sh first!${NC}"
    exit 1
fi

check_app() {
	local name="$1"
	local url="$2"

	echo "--- $name ---"

	local current
	if [[ "$name" == "Antigravity CLI" ]]; then
		local current_url=$(jq -r ".\"$name\".\"x86_64-linux\".url" "$VERSIONS_JSON" 2>/dev/null || echo "")
		current=$(echo "$current_url" | grep -oP 'antigravity-cli/\K[0-9.]+-[0-9]+' || echo "unknown")
	else
		local current_url=$(jq -r ".\"$name\".\"x86_64-linux\".url" "$VERSIONS_JSON" 2>/dev/null || echo "")
		current=$(echo "$current_url" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+-[0-9]+' || echo "unknown")
	fi

	echo -e "Current version: $current"

	local latest
	if [[ "$name" == "Antigravity CLI" ]]; then
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

check_app "Antigravity 2.0" "https://antigravity-auto-updater-974169037036.us-central1.run.app/releases"
check_app "Antigravity CLI" "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json"
check_app "Antigravity IDE" "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/releases"
