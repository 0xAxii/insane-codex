#!/usr/bin/env bash
set -euo pipefail

upstream_tag="${1:-rust-v0.165.0}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
patch_file="${repo_dir}/patches/no-client-guardrails.patch"
target_dir="${CODEX_BUILD_TARGET_DIR:-${repo_dir}/.build/target}"
dist_dir="${repo_dir}/dist"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/insane-codex.XXXXXX")"
source_dir="${temp_dir}/codex"

cleanup() {
  rm -rf "${temp_dir}"
}
trap cleanup EXIT

if [[ ! -f "${patch_file}" ]]; then
  echo "missing patch: ${patch_file}" >&2
  exit 1
fi

git clone --filter=blob:none --depth 1 --branch "${upstream_tag}" \
  https://github.com/openai/codex.git "${source_dir}"
git -C "${source_dir}" apply --check "${patch_file}"
git -C "${source_dir}" apply "${patch_file}"

mkdir -p "${target_dir}" "${dist_dir}"
CARGO_TARGET_DIR="${target_dir}" \
  cargo build --manifest-path "${source_dir}/codex-rs/Cargo.toml" --release --bin codex

artifact="${dist_dir}/codex-${upstream_tag}-$(uname -m)"
install -m 755 "${target_dir}/release/codex" "${artifact}"

"${artifact}" --version
if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "${artifact}"
else
  sha256sum "${artifact}"
fi

echo "built: ${artifact}"

