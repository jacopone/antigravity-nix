#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const INSTALL_SCRIPT_URL = 'https://antigravity.google/cli/install.sh';
const PLATFORMS = [
  'darwin_amd64',
  'darwin_arm64',
  'linux_amd64',
  'linux_arm64',
  'linux_amd64_musl',
  'linux_arm64_musl'
];

const useColor = !process.argv.includes('--nocolor');
const GREEN = useColor ? '\x1b[32m' : '';
const YELLOW = useColor ? '\x1b[33m' : '';
const RED = useColor ? '\x1b[31m' : '';
const BLUE = useColor ? '\x1b[34m' : '';
const NC = useColor ? '\x1b[0m' : '';

function logInfo(msg) {
  console.error(`${BLUE}ℹ️ [INFO]${NC} ${msg}`);
}
function logSuccess(msg) {
  console.error(`${GREEN}✅ [SUCCESS]${NC} ${msg}`);
}
function logWarn(msg) {
  console.error(`${YELLOW}⚠️ [WARN]${NC} ${msg}`);
}
function logError(msg) {
  console.error(`${RED}❌ [ERROR]${NC} ${msg}`);
}

async function main() {
  try {
    // 1. Download install.sh into a tmp file
    logInfo(`Downloading installer script from ${INSTALL_SCRIPT_URL}...`);
    const response = await fetch(INSTALL_SCRIPT_URL);
    if (!response.ok) {
      throw new Error(`Failed to download install.sh: HTTP ${response.status}`);
    }
    const scriptContent = await response.text();

    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'antigravity-cli-'));
    const tempFilePath = path.join(tempDir, 'install.sh');
    fs.writeFileSync(tempFilePath, scriptContent);
    logInfo(`Downloaded installer script to: ${tempFilePath}`);

    // 2. Parse script to find DOWNLOAD_BASE_URL
    const match = scriptContent.match(/DOWNLOAD_BASE_URL="([^"]+)"/);
    if (!match) {
      throw new Error('Could not find DOWNLOAD_BASE_URL in install.sh');
    }
    const downloadBaseUrl = match[1];
    logInfo(`Extracted DOWNLOAD_BASE_URL: ${downloadBaseUrl}`);

    // 3. Download manifests for each platform
    const outputDir = path.join(__dirname, '../artifacts/antigravity-cli--manifests');
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    logInfo('Fetching platform manifests...');
    for (const platform of PLATFORMS) {
      const manifestUrl = `${downloadBaseUrl}/manifests/${platform}.json`;
      logInfo(`Fetching ${manifestUrl}...`);
      try {
        const manifestRes = await fetch(manifestUrl);
        if (!manifestRes.ok) {
          logWarn(`Manifest not found or error for ${platform} (HTTP ${manifestRes.status})`);
          continue;
        }
        const manifestData = await manifestRes.json();
        const outputPath = path.join(outputDir, `${platform}.json`);
        fs.writeFileSync(outputPath, JSON.stringify(manifestData, null, 2));
        logSuccess(`Saved manifest for ${platform} to ${outputPath}`);
      } catch (manifestErr) {
        logError(`Failed to fetch manifest for ${platform}: ${manifestErr.message}`);
      }
    }

    logSuccess('Finished downloading all manifests.');
  } catch (err) {
    logError(err.message);
    process.exit(1);
  }
}

main();
