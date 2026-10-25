#!/usr/bin/env bash
set -euo pipefail

repo="0xAxii/insane-codex"
install_dir="${INSANE_CODEX_INSTALL_DIR:-${HOME}/.local/bin}"
release_base="${INSANE_CODEX_RELEASE_BASE:-https://github.com/${repo}/releases/latest/download}"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    target="aarch64-apple-darwin"
    ;;
  Darwin-x86_64)
    target="x86_64-apple-darwin"
    ;;
  Linux-x86_64)
    target="x86_64-unknown-linux-gnu"
    ;;
  Linux-aarch64 | Linux-arm64)
    target="aarch64-unknown-linux-gnu"
    ;;
  *)
    echo "unsupported platform: $(uname -s) $(uname -m)" >&2
    exit 1
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

asset="insane-codex-${target}.tar.gz"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/insane-codex-install.XXXXXX")"

cleanup() {
  rm -rf "${temp_dir}"
}
trap cleanup EXIT

curl --fail --location --retry 3 --silent --show-error \
  "${release_base}/${asset}" -o "${temp_dir}/${asset}"
curl --fail --location --retry 3 --silent --show-error \
  "${release_base}/${asset}.sha256" -o "${temp_dir}/${asset}.sha256"

expected="$(awk 'NR == 1 { print $1 }' "${temp_dir}/${asset}.sha256")"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "${temp_dir}/${asset}" | awk '{ print $1 }')"
else
  actual="$(shasum -a 256 "${temp_dir}/${asset}" | awk '{ print $1 }')"
fi

if [[ -z "${expected}" || "${actual}" != "${expected}" ]]; then
  echo "checksum verification failed" >&2
  exit 1
fi

tar -C "${temp_dir}" -xzf "${temp_dir}/${asset}"
mkdir -p "${install_dir}"
install -m 755 "${temp_dir}/insane-codex" "${install_dir}/insane-codex"

echo "installed: ${install_dir}/insane-codex"
"${install_dir}/insane-codex" --version

case ":${PATH}:" in
  *":${install_dir}:"*) ;;
  *)
    echo
    echo "Add this directory to PATH before running insane-codex:"
    echo "  export PATH=\"${install_dir}:\$PATH\""
    ;;
esac
