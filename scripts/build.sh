#!/usr/bin/env bash
set -euo pipefail

upstream_tag="${1:-rust-v0.172.0}"
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
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) target="aarch64-apple-darwin" ;;
  Darwin-x86_64) target="x86_64-apple-darwin" ;;
  Linux-aarch64) target="aarch64-unknown-linux-gnu" ;;
  Linux-x86_64) target="x86_64-unknown-linux-gnu" ;;
  *) echo "unsupported build platform" >&2; exit 1 ;;
esac

package_dir="${dist_dir}/insane-codex-${upstream_tag}-${target}"
CODEX_REPO_ROOT="${source_dir}" CARGO_TARGET_DIR="${target_dir}" \
  python3 "${source_dir}/scripts/build_codex_package.py" \
    --target "${target}" --cargo-profile release --strip none \
    --package-dir "${package_dir}"
mv "${package_dir}/bin/codex" "${package_dir}/bin/insane-codex"
python3 -c 'import json, pathlib, sys; p = pathlib.Path(sys.argv[1]); data = json.loads(p.read_text()); data["entrypoint"] = "bin/insane-codex"; p.write_text(json.dumps(data, indent=2) + "\n")' "${package_dir}/codex-package.json"

artifact="${package_dir}/bin/insane-codex"

"${artifact}" --version
if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "${artifact}"
else
  sha256sum "${artifact}"
fi

echo "built: ${artifact}"

