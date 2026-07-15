// ---------------------------------------------------------------------------
//  HarmonyOS hvigor-wrapper (bootstraps hvigor from npm)
// ---------------------------------------------------------------------------
"use strict";

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const hvigorConfigPath = path.join(__dirname, 'hvigor-config.json5');

function readHvigorConfig() {
  if (!fs.existsSync(hvigorConfigPath)) {
    console.error('Error: hvigor-config.json5 not found in hvigor/ directory');
    process.exit(1);
  }
  // Simple JSON5 parsing (strip comments)
  let content = fs.readFileSync(hvigorConfigPath, 'utf-8');
  content = content.replace(/\/\/.*$/gm, '').replace(/\/\*[\s\S]*?\*\//g, '');
  return JSON.parse(content);
}

function ensureNodeModules() {
  const config = readHvigorConfig();
  const hvigorVersion = config.hvigorVersion;
  const dependencies = config.dependencies || {};

  const nodeModulesPath = path.join(process.cwd(), 'node_modules');
  const hvigorPath = path.join(nodeModulesPath, '@ohos', 'hvigor');

  if (!fs.existsSync(hvigorPath)) {
    console.log(`[hvigor-wrapper] Installing @ohos/hvigor@${hvigorVersion}...`);
    const packages = [`@ohos/hvigor@${hvigorVersion}`];
    for (const [dep, version] of Object.entries(dependencies)) {
      packages.push(`${dep}@${version}`);
    }
    const npmRegistry = 'https://repo.harmonyos.com/npm/';
    execSync(`npm install --save-dev ${packages.join(' ')} --registry=${npmRegistry}`, {
      stdio: 'inherit',
      cwd: process.cwd()
    });
  }
}

function main() {
  try {
    ensureNodeModules();
    const hvigorMain = require(path.join(process.cwd(), 'node_modules', '@ohos', 'hvigor'));
    if (typeof hvigorMain.execute === 'function') {
      hvigorMain.execute(process.argv.slice(2));
    } else {
      console.error('Error: @ohos/hvigor execute function not found');
      process.exit(1);
    }
  } catch (e) {
    console.error(`[hvigor-wrapper] Error: ${e.message}`);
    process.exit(1);
  }
}

main();
