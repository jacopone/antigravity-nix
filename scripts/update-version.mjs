#!/usr/bin/env node
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

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

function runCmd(cmd) {
  logInfo(`Running: ${cmd}`);
  return execSync(cmd, { stdio: 'inherit' });
}

function getVersionFromUrl(url) {
  if (!url) return 'unknown';
  const match = url.match(/\/([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)\//);
  return match ? match[1] : 'unknown';
}

async function main() {
  logInfo("Starting Google Antigravity update orchestration...");

  const extraArgs = process.argv.includes('--nocolor') ? ' --nocolor' : '';

  // 1. Run scrapers and fetchers (Stage 01)
  logInfo("Step 1: Scraping Google Antigravity download page...");
  runCmd(`node scripts/antigravity-2-and-ide--1--scrape-download-page.mjs${extraArgs}`);

  logInfo("Step 2: Fetching Antigravity CLI manifests...");
  runCmd(`node scripts/antigravity-cli--parse-install-script-and-download-manifests.mjs${extraArgs}`);

  // 2. Check changes using git status
  logInfo("Checking if scraped files differ from repository version...");
  const statusStr = execSync('git status --porcelain', { encoding: 'utf8' });
  const lines = statusStr.split('\n');

  let linksChanged = false;
  let cliChanged = false;

  for (const line of lines) {
    if (line.includes('artifacts/antigravity-2-and-ide--1--scraped-links.json')) {
      linksChanged = true;
    }
    if (line.includes('artifacts/antigravity-cli--manifests/')) {
      cliChanged = true;
    }
  }

  // 3. Check if any update is needed
  if (!linksChanged && !cliChanged) {
    logSuccess("No changes detected. All packages are already up to date!");
    console.log(JSON.stringify({ status: "up-to-date", linksChanged: false, cliChanged: false }, null, 2));
    process.exit(0);
  }

  // 4. Run Stage 02 only if desktop links have changed
  if (linksChanged) {
    logWarn("Desktop download links have changed! Running Step 3 (prefetch & hash)...");
    runCmd(`node scripts/antigravity-2-and-ide--2--prefetch-links.mjs${extraArgs}`);
  } else {
    logInfo("Desktop download links have not changed.");
  }

  if (cliChanged) {
    logWarn("CLI manifests have changed!");
  } else {
    logInfo("CLI manifests have not changed.");
  }

  // 5. Git stage and test Nix builds
  if (fs.existsSync('.git')) {
    logInfo("Staging updated JSON and Nix files in Git...");
    runCmd('git add artifacts/antigravity-2-and-ide--1--scraped-links.json artifacts/antigravity-2-and-ide--2--prefetched-sha256.json artifacts/antigravity-cli--manifests/*.json package.nix cli.nix google-antigravity2.nix google-antigravity-ide.nix flake.nix');
  }

  logInfo("Testing builds under Nix...");
  runCmd('nix build .#google-antigravity-ide --no-link');
  runCmd('nix build .#google-antigravity2 --no-link');
  runCmd('nix build .#google-antigravity-cli --no-link');
  runCmd('nix build .#google-antigravity2-no-fhs --no-link');
  runCmd('nix build .#google-antigravity-ide-no-fhs --no-link');

  // 6. Git Commit
  if (fs.existsSync('.git')) {
    logInfo("Committing changes to Git...");
    const links = JSON.parse(fs.readFileSync('artifacts/antigravity-2-and-ide--1--scraped-links.json', 'utf8'));
    const cliData = JSON.parse(fs.readFileSync('artifacts/antigravity-cli--manifests/linux_amd64.json', 'utf8'));

    const appVersion = getVersionFromUrl(links["Antigravity 2.0"]?.linux?.x64);
    const ideVersion = getVersionFromUrl(links["Antigravity IDE"]?.linux?.x64);
    const cliVersion = cliData.version;

    runCmd(`git commit -m "chore: update Google Antigravity to App ${appVersion}, IDE ${ideVersion}, CLI ${cliVersion}"`);
  }

  logSuccess("Update process successfully complete!");
  console.log(JSON.stringify({
    status: "updated",
    linksChanged,
    cliChanged
  }, null, 2));
}

main().catch(err => {
  logError(`FATAL ERROR: ${err.message}`);
  process.exit(1);
});
