#!/usr/bin/env node

"use strict";

const path = require("node:path");
const { spawn } = require("node:child_process");

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

if (!architecture || !system) {
  console.error(`insane: unsupported platform: ${process.platform} ${process.arch}`);
  process.exit(1);
}

const target = `${architecture}-${system}`;
const executable = process.platform === "win32" ? "insane-codex.exe" : "insane-codex";
const binary = path.resolve(__dirname, "..", "vendor", target, executable);
const child = spawn(binary, process.argv.slice(2), { stdio: "inherit" });

// Keep the launcher alive while the TUI handles Ctrl-C itself. Both processes
// share the foreground process group, so the child receives the terminal signal.
process.on("SIGINT", () => {});

child.on("error", (error) => {
  console.error(`insane: failed to start ${binary}: ${error.message}`);
  process.exit(1);
});

child.on("exit", (code, signal) => {
  if (signal) {
    const signalNumbers = { SIGHUP: 1, SIGINT: 2, SIGTERM: 15 };
    process.exit(128 + (signalNumbers[signal] || 1));
  }
  process.exit(code === null ? 1 : code);
});
