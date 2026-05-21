#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const useColor = !process.argv.includes('--nocolor');
const GREEN = useColor ? '\x1b[32m' : '';
// const YELLOW = useColor ? '\x1b[33m' : '';
const RED = useColor ? '\x1b[31m' : '';
const BLUE = useColor ? '\x1b[34m' : '';
const NC = useColor ? '\x1b[0m' : '';

function logInfo(msg) {
  console.error(`${BLUE}ℹ️ [INFO]${NC} ${msg}`);
}
function logSuccess(msg) {
  console.error(`${GREEN}✅ [SUCCESS]${NC} ${msg}`);
}
function logError(msg) {
  console.error(`${RED}❌ [ERROR]${NC} ${msg}`);
}

async function getSRIHash(url) {
  logInfo(`Prefetching and hashing: ${url}`);
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: HTTP ${res.status}`);
  }
  const buffer = await res.arrayBuffer();
  const hash = crypto.createHash('sha256').update(Buffer.from(buffer)).digest('base64');
  return `sha256-${hash}`;
}

async function main() {
  const linksPath = path.join(__dirname, '../artifacts/antigravity-2-and-ide--1--scraped-links.json');
  if (!fs.existsSync(linksPath)) {
    logError(`File not found: ${linksPath}. Run stage 1 scraping first.`);
    process.exit(1);
  }

  const links = JSON.parse(fs.readFileSync(linksPath, 'utf8'));
  const shaResult = {
    "Antigravity 2.0": {
      "macos": {
        "apple silicon": null,
        "intel": null
      },
      "linux": {
        "x64": null,
        "arm64": null
      }
    },
    "Antigravity IDE": {
      "macos": {
        "apple silicon": null,
        "intel": null
      },
      "linux": {
        "x64": null,
        "arm64": null
      }
    }
  };

  try {
    for (const appType of ["Antigravity 2.0", "Antigravity IDE"]) {
      // macOS Apple Silicon
      if (links[appType].macos["apple silicon"]) {
        shaResult[appType].macos["apple silicon"] = await getSRIHash(links[appType].macos["apple silicon"]);
      }
      // macOS Intel
      if (links[appType].macos["intel"]) {
        shaResult[appType].macos["intel"] = await getSRIHash(links[appType].macos["intel"]);
      }
      // Linux x64
      if (links[appType].linux["x64"]) {
        shaResult[appType].linux["x64"] = await getSRIHash(links[appType].linux["x64"]);
      }
      // Linux arm64
      if (links[appType].linux["arm64"]) {
        shaResult[appType].linux["arm64"] = await getSRIHash(links[appType].linux["arm64"]);
      }
    }

    const outputPath = path.join(__dirname, '../artifacts/antigravity-2-and-ide--2--prefetched-sha256.json');
    // Ensure parent folder exists
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(outputPath, JSON.stringify(shaResult, null, 2));
    logSuccess(`Wrote hashes to ${outputPath}`);
    console.log(JSON.stringify(shaResult, null, 2));
  } catch (err) {
    logError(err.message || err);
    process.exit(1);
  }
}

main();
