#!/usr/bin/env node
import { chromium } from 'playwright-chromium';
import fs from 'fs';
import path from 'path';
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

async function main() {
  const chromePath = process.env.CHROME_BIN ||
    process.env.CHROME_PATH ||
    '/run/current-system/sw/bin/google-chrome-stable';

  const useSystemChrome = fs.existsSync(chromePath);
  const browser = await chromium.launch({
    headless: true,
    ...(useSystemChrome && { executablePath: chromePath }),
  });

  try {
    const page = await browser.newPage();
    logInfo('Navigating to https://antigravity.google/download');
    await page.goto('https://antigravity.google/download', {
      waitUntil: 'networkidle',
      timeout: 30000,
    });
    // Wait for dynamic angular content to render
    await page.waitForTimeout(3000);

    const scraped = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('a'))
        .map(a => ({
          text: a.innerText.trim(),
          href: a.getAttribute('href')
        }))
        .filter(l => l.href && (l.href.includes('antigravity-hub') || l.href.includes('edgedl') || l.href.includes('Antigravity')));
    });

    const result = {
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

    for (const link of scraped) {
      const href = link.href;
      // Determine if it is IDE or 2.0
      const isIde = href.includes('IDE') || href.includes('edgedl.me.gvt1.com');
      const target = isIde ? result["Antigravity IDE"] : result["Antigravity 2.0"];

      if (href.includes('darwin-arm') || href.includes('darwin-arm64')) {
        target.macos["apple silicon"] = href;
      } else if (href.includes('darwin-x64')) {
        target.macos["intel"] = href;
      } else if (href.includes('linux-x64')) {
        target.linux["x64"] = href;
      } else if (href.includes('linux-arm')) {
        target.linux["arm64"] = href;
      }
    }

    const outputPath = path.join(__dirname, '../artifacts/antigravity-2-and-ide--1--scraped-links.json');
    // Ensure parent folder exists
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(outputPath, JSON.stringify(result, null, 2));
    logSuccess(`Wrote links to ${outputPath}`);
    console.log(JSON.stringify(result, null, 2));
  } catch (err) {
    logError(err.message || err);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

main();
