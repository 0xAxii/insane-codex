#!/usr/bin/env bash
set -euo pipefail

repo="0xAxii/insane-codex"
version="${INSANE_CODEX_VERSION:-0.167.0}"
bin_dir="${INSANE_CODEX_INSTALL_DIR:-${HOME}/.local/bin}"
libexec_root="${INSANE_CODEX_LIBEXEC_DIR:-${HOME}/.local/libexec}"
version_dir="${libexec_root}/insane-codex-v${version}"
binary="${version_dir}/insane-codex"
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

tar -C "${temp_dir}" -xzf "${temp_dir}/${asset}"
mkdir -p "${version_dir}" "${bin_dir}"
install -m 755 "${temp_dir}/insane-codex" "${binary}"
"${binary}" --version
ln -sfn "${binary}" "${bin_dir}/insane-codex"

echo "installed: ${binary}"
echo "entrypoint: ${bin_dir}/insane-codex"
"${bin_dir}/insane-codex" --version

case ":${PATH}:" in
  *":${bin_dir}:"*) ;;
  *)
    echo
    echo "Add this directory to PATH before running insane-codex:"
    echo "  export PATH=\"${bin_dir}:\$PATH\""
    ;;
esac
