#!/usr/bin/env node
// Integration test: builds every package and smoke-checks the resulting binaries.
// Linux-oriented (matches CI); run locally with `node scripts/test.mjs`.
import { exec } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.join(__dirname, '..');

const useColor = !process.argv.includes('--nocolor');
const GREEN = useColor ? '\x1b[32m' : '';
const YELLOW = useColor ? '\x1b[33m' : '';
const RED = useColor ? '\x1b[31m' : '';
const BLUE = useColor ? '\x1b[34m' : '';
const NC = useColor ? '\x1b[0m' : '';

const logInfo = (m) => console.log(`${BLUE}ℹ️ [INFO]${NC} ${m}`);
const logSuccess = (m) => console.log(`${GREEN}✅ [SUCCESS]${NC} ${m}`);
const logWarn = (m) => console.log(`${YELLOW}⚠️ [WARN]${NC} ${m}`);
const logError = (m) => console.log(`${RED}❌ [ERROR]${NC} ${m}`);

function runBuild(name, attr, outLink) {
  return new Promise((resolve, reject) => {
    logInfo(`Starting build for ${GREEN}${name}${NC} (.#${attr})...`);
    exec(`nix build .#${attr} --out-link ${outLink}`, { cwd: repoRoot }, (error, stdout, stderr) => {
      if (error) {
        logError(`Build failed for ${name} (.#${attr})`);
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
    exec(cmd, { cwd: repoRoot }, (error, stdout, stderr) => {
      if (error) reject(new Error(`Command "${cmd}" failed: ${stderr || stdout}`));
      else resolve(stdout.trim());
    });
  });
}

// Attribute names match flake.nix; binary names match pkgs/package.nix
// (app -> "antigravity", ide -> "antigravity-ide", cli -> "agy").
const builds = [
  { name: 'App FHS',          attr: 'google-antigravity',             outLink: 'result-test-app',        bin: 'bin/antigravity' },
  { name: 'App pure (no-FHS)', attr: 'google-antigravity-no-fhs',     outLink: 'result-test-app-no-fhs', bin: 'bin/antigravity' },
  { name: 'IDE FHS',          attr: 'google-antigravity-ide',         outLink: 'result-test-ide',        bin: 'bin/antigravity-ide' },
  { name: 'IDE pure (no-FHS)', attr: 'google-antigravity-ide-no-fhs', outLink: 'result-test-ide-no-fhs', bin: 'bin/antigravity-ide' },
  { name: 'CLI',              attr: 'google-antigravity-cli',         outLink: 'result-test-cli',        bin: 'bin/agy' },
];

function expectedCliVersion() {
  const versions = JSON.parse(fs.readFileSync(path.join(repoRoot, 'artifacts/versions.json'), 'utf8'));
  const url = versions['Antigravity CLI']?.['x86_64-linux']?.url ?? '';
  const m = url.match(/\/([0-9]+\.[0-9]+\.[0-9]+-[0-9]+)\//);
  return m ? m[1] : null;
}

async function main() {
  logInfo('Building all targets concurrently...');
  try {
    await Promise.all(builds.map((b) => runBuild(b.name, b.attr, b.outLink)));

    logInfo('Checking that each package produced its expected binary...');
    for (const b of builds) {
      const p = path.join(repoRoot, b.outLink, b.bin);
      if (!fs.existsSync(p)) throw new Error(`${b.name}: expected binary not found at ${b.outLink}/${b.bin}`);
      logSuccess(`${b.name}: ${b.bin} present.`);
    }

    // CLI: assert it runs and reports the version we packaged. `agy changelog`
    // is exercised for a non-zero exit only (its text changes between releases).
    const cliBin = path.join(repoRoot, 'result-test-cli/bin/agy');
    const expected = expectedCliVersion();
    const versionOut = await runVerify(`${cliBin} --version`);
    console.log(versionOut);
    if (expected && !versionOut.includes(expected)) {
      throw new Error(`CLI --version "${versionOut}" does not contain expected version "${expected}"`);
    }
    logSuccess(`CLI --version reports the packaged version (${expected ?? 'unknown'}).`);
    await runVerify(`${cliBin} changelog`);
    logSuccess('CLI `changelog` ran successfully.');

    logSuccess('🎉 All integration tests passed!');
  } catch (err) {
    logError(`FATAL: ${err.message}`);
    process.exitCode = 1;
  } finally {
    logInfo('Cleaning up test out-links...');
    for (const b of builds) {
      const p = path.join(repoRoot, b.outLink);
      try { if (fs.existsSync(p)) fs.unlinkSync(p); }
      catch (e) { logWarn(`Failed to remove ${b.outLink}: ${e.message}`); }
    }
  }
}

main();
