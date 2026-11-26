#!/usr/bin/env node

"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const https = require("node:https");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const manifest = require("./manifest.json");

const MAX_REDIRECTS = 10;

function targetTriple() {
  const architectures = {
    arm64: "aarch64",
    x64: "x86_64",
  };
  const systems = {
    darwin: "apple-darwin",
    linux: "unknown-linux-gnu",
    win32: "pc-windows-msvc",
  };
  const architecture = architectures[process.arch];
  const system = systems[process.platform];
  return architecture && system ? `${architecture}-${system}` : null;
}

function download(url, destination, redirects = 0) {
  return new Promise((resolve, reject) => {
    if (redirects > MAX_REDIRECTS) {
      reject(new Error(`too many redirects while downloading ${url}`));
      return;
    }

    const request = https.get(
      url,
      {
        headers: {
          Accept: "application/octet-stream",
          "User-Agent": `insane-codex-npm/${require("../package.json").version}`,
        },
      },
      (response) => {
        const location = response.headers.location;
        if (response.statusCode >= 300 && response.statusCode < 400 && location) {
          response.resume();
          const nextUrl = new URL(location, url).toString();
          download(nextUrl, destination, redirects + 1).then(resolve, reject);
          return;
        }
        if (response.statusCode !== 200) {
          response.resume();
          reject(new Error(`download failed with HTTP ${response.statusCode}: ${url}`));
          return;
        }

        const output = fs.createWriteStream(destination, { mode: 0o600 });
        response.pipe(output);
        output.on("finish", () => output.close(resolve));
        output.on("error", reject);
      },
    );
    request.on("error", reject);
  });
}

function sha256(file) {
  const hash = crypto.createHash("sha256");
  hash.update(fs.readFileSync(file));
  return hash.digest("hex");
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", stdio: "pipe", ...options });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    const details = [result.stdout, result.stderr].filter(Boolean).join("\n").trim();
    throw new Error(`${command} failed${details ? `:\n${details}` : ""}`);
  }
  return `${result.stdout || ""}${result.stderr || ""}`.trim();
}

function extract(archive, destination) {
  fs.mkdirSync(destination, { recursive: true });
  if (process.platform === "win32") {
    run("powershell.exe", [
      "-NoLogo",
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      "Expand-Archive -LiteralPath $env:INSANE_CODEX_ARCHIVE -DestinationPath $env:INSANE_CODEX_DESTINATION -Force",
    ], {
      env: {
        ...process.env,
        INSANE_CODEX_ARCHIVE: archive,
        INSANE_CODEX_DESTINATION: destination,
      },
    });
    return;
  }
  run("tar", ["-xzf", archive, "-C", destination]);
}

async function main() {
  if (process.env.INSANE_CODEX_SKIP_DOWNLOAD === "1") {
    console.log("insane-codex: skipped binary download (INSANE_CODEX_SKIP_DOWNLOAD=1)");
    return;
  }

  const target = targetTriple();
  const asset = target && manifest.assets[target];
  if (!target || !asset) {
    throw new Error(`unsupported platform: ${process.platform} ${process.arch}`);
  }

  const packageRoot = path.resolve(__dirname, "..");
  const vendorDir = path.join(packageRoot, "npm", "vendor", target);
  const binaryName = process.platform === "win32" ? "insane-codex.exe" : "insane-codex";
  const binary = path.join(vendorDir, "bin", binaryName);
  const suffix = process.platform === "win32" ? ".exe" : "";
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "insane-codex-npm-"));
  const archive = path.join(temporary, asset.file);
  const url = `https://github.com/${manifest.repository}/releases/download/${manifest.releaseTag}/${asset.file}`;

  try {
    console.log(`insane-codex: downloading ${asset.file}`);
    await download(url, archive);
    const actualHash = sha256(archive);
    if (actualHash !== asset.sha256) {
      throw new Error(`SHA-256 mismatch for ${asset.file}: expected ${asset.sha256}, received ${actualHash}`);
    }

    fs.rmSync(vendorDir, { recursive: true, force: true });
    extract(archive, vendorDir);
    if (!fs.existsSync(binary)) {
      throw new Error(`archive did not contain ${binaryName}`);
    }
    for (const relative of [
      "codex-package.json",
      path.join("bin", `codex-code-mode-host${suffix}`),
      path.join("bin", `codex-exec-server${suffix}`),
      path.join("codex-path", `rg${suffix}`),
      ...(process.platform === "linux" ? [path.join("codex-resources", "bwrap")] : []),
      ...(process.platform === "win32" ? [
        path.join("codex-resources", "codex-command-runner.exe"),
        path.join("codex-resources", "codex-windows-sandbox-setup.exe"),
      ] : []),
    ]) {
      if (!fs.existsSync(path.join(vendorDir, relative))) {
        throw new Error(`archive did not contain ${relative}`);
      }
    }
    if (process.platform !== "win32") {
      fs.chmodSync(binary, 0o755);
    }

    const version = run(binary, ["--version"]);
    if (!version.includes(manifest.codexVersion)) {
      throw new Error(`unexpected binary version: ${version}`);
    }
    console.log(`insane-codex: installed ${version} for ${target}`);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(`insane-codex postinstall failed: ${error.message}`);
  process.exit(1);
});
