#!/usr/bin/env node
import { exec } from 'child_process';
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
  console.log(`${BLUE}ℹ️ [INFO]${NC} ${msg}`);
}
function logSuccess(msg) {
  console.log(`${GREEN}✅ [SUCCESS]${NC} ${msg}`);
}
function logWarn(msg) {
  console.log(`${YELLOW}⚠️ [WARN]${NC} ${msg}`);
}
function logError(msg) {
  console.log(`${RED}❌ [ERROR]${NC} ${msg}`);
}

function runBuild(name, attr, outLink) {
  return new Promise((resolve, reject) => {
    logInfo(`Starting build for ${GREEN}${name}${NC} (${attr})...`);
    exec(`nix build .#${attr} --out-link ${outLink}`, (error, stdout, stderr) => {
      if (error) {
        logError(`Build failed for ${name} (${attr})`);
        console.error(stderr || stdout);
        reject(error);
      } else {
        logSuccess(`Build succeeded for ${GREEN}${name}${NC}!`);
        resolve();
      }
    });
  });
}

function runVerify(cmd) {
  return new Promise((resolve, reject) => {
    exec(cmd, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(`Command "${cmd}" failed: ${stderr || stdout}`));
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

async function main() {
  logInfo("Starting Google Antigravity isolated parallel integration tests...");

  const builds = [
    { name: "IDE FHS", attr: "google-antigravity-ide", outLink: "result-test-ide" },
    { name: "IDE pure (no-FHS)", attr: "google-antigravity-ide-no-fhs", outLink: "result-test-ide-no-fhs" },
    { name: "App FHS", attr: "google-antigravity2", outLink: "result-test-app" },
    { name: "App pure (no-FHS)", attr: "google-antigravity2-no-fhs", outLink: "result-test-app-no-fhs" },
    { name: "CLI", attr: "google-antigravity-cli", outLink: "result-test-cli" }
  ];

  try {
    // 1. Build all packages in parallel
    logInfo("Building all 5 targets concurrently...");
    await Promise.all(builds.map(b => runBuild(b.name, b.attr, b.outLink)));

    // 2. Perform validations
    logInfo("Running assertions on the built packages...");

    // Validate CLI changelog and version
    const cliPath = path.join(__dirname, "../result-test-cli/bin/agy");
    if (!fs.existsSync(cliPath)) {
      throw new Error(`CLI executable not found at ${cliPath}`);
    }

    logInfo("Testing CLI changelog output...");
    const changelogOut = await runVerify(`${cliPath} changelog`);
    console.log(changelogOut);
    if (!changelogOut.includes("Initial release of the Antigravity CLI.")) {
      throw new Error("CLI changelog did not contain expected initial release message.");
    }
    logSuccess("CLI changelog output validation passed!");

    logInfo("Testing CLI --version output...");
    const versionOut = await runVerify(`${cliPath} --version`);
    console.log(versionOut);
    
    // Load expected version from manifest
    const manifestPath = path.join(__dirname, "../artifacts/antigravity-cli--manifests/linux_amd64.json");
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    if (!versionOut.includes(manifest.version)) {
      throw new Error(`CLI version output "${versionOut}" does not contain expected version "${manifest.version}"`);
    }
    logSuccess("CLI version output validation passed!");

    // Validate Desktop paths
    const idePath = path.join(__dirname, "../result-test-ide/bin/antigravity-ide");
    if (!fs.existsSync(idePath)) {
      throw new Error(`IDE executable not found at ${idePath}`);
    }
    logSuccess("IDE FHS executable exists and path is correct!");

    const appPath = path.join(__dirname, "../result-test-app/bin/antigravity");
    if (!fs.existsSync(appPath)) {
      throw new Error(`App executable not found at ${appPath}`);
    }
    logSuccess("App FHS executable exists and path is correct!");

    logSuccess("🎉 All integration tests passed successfully!");
  } catch (err) {
    logError(`FATAL ERROR: ${err.message}`);
    process.exit(1);
  } finally {
    logInfo("Cleaning up test out-links...");
    for (const b of builds) {
      if (fs.existsSync(b.outLink)) {
        try {
          fs.unlinkSync(b.outLink);
        } catch (e) {
          logWarn(`Failed to remove out-link ${b.outLink}: ${e.message}`);
        }
      }
    }
    logInfo("Cleanup complete.");
  }
}

main();
