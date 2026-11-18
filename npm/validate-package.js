#!/usr/bin/env node

"use strict";

const fs = require("node:fs");
const path = require("node:path");
const packageJson = require("../package.json");
const manifest = require("./manifest.json");

const expectedPackageVersion = `${manifest.codexVersion}-insane.1`;
if (packageJson.version !== expectedPackageVersion) {
  throw new Error(`package version ${packageJson.version} does not match ${expectedPackageVersion}`);
}

const expectedTargets = [
  "aarch64-apple-darwin",
  "aarch64-pc-windows-msvc",
  "aarch64-unknown-linux-gnu",
  "x86_64-apple-darwin",
  "x86_64-pc-windows-msvc",
  "x86_64-unknown-linux-gnu",
];

for (const target of expectedTargets) {
  const asset = manifest.assets[target];
  if (!asset || !/^[a-f0-9]{64}$/.test(asset.sha256)) {
    throw new Error(`missing or invalid manifest entry for ${target}`);
  }
}

for (const relative of ["postinstall.js", "bin/insane.js", "manifest.json"]) {
  if (!fs.existsSync(path.join(__dirname, relative))) {
    throw new Error(`missing npm package file: npm/${relative}`);
  }
}

console.log(`validated ${packageJson.name}@${packageJson.version} for ${expectedTargets.length} targets`);
