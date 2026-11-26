#!/usr/bin/env bash
set -euo pipefail

repo="0xAxii/insane-codex"
version="${INSANE_CODEX_VERSION:-0.172.0-insane.4}"
bin_dir="${INSANE_CODEX_INSTALL_DIR:-${HOME}/.local/bin}"
libexec_root="${INSANE_CODEX_LIBEXEC_DIR:-${HOME}/.local/libexec}"
version_dir="${libexec_root}/insane-codex-v${version}"
binary="${version_dir}/bin/insane-codex"
release_base="${INSANE_CODEX_RELEASE_BASE:-https://github.com/${repo}/releases/download/v${version}}"

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
staging_dir=""

cleanup() {
  rm -rf "${temp_dir}"
  if [[ -n "${staging_dir}" ]]; then
    rm -rf "${staging_dir}"
  fi
}
trap cleanup EXIT

curl --fail --location --retry 3 --silent --show-error \
  "${release_base}/${asset}" -o "${temp_dir}/${asset}"

tar -C "${temp_dir}" -xzf "${temp_dir}/${asset}"
for required in codex-package.json bin/insane-codex bin/codex-code-mode-host bin/codex-exec-server codex-path/rg; do
  test -f "${temp_dir}/${required}" || { echo "missing package file: ${required}" >&2; exit 1; }
done
mkdir -p "${libexec_root}" "${bin_dir}"
staging_dir="$(mktemp -d "${libexec_root}/.insane-codex-stage.XXXXXX")"
for directory in bin codex-path codex-resources; do
  cp -R "${temp_dir}/${directory}" "${staging_dir}/${directory}"
done
cp "${temp_dir}/codex-package.json" "${staging_dir}/codex-package.json"
"${staging_dir}/bin/insane-codex" --version
"${staging_dir}/bin/codex-code-mode-host" --help >/dev/null

backup_dir="${version_dir}.backup.$$"
if [[ -e "${version_dir}" ]]; then
  mv "${version_dir}" "${backup_dir}"
fi
if ! mv "${staging_dir}" "${version_dir}"; then
  if [[ -e "${backup_dir}" ]]; then
    mv "${backup_dir}" "${version_dir}"
  fi
  exit 1
fi
staging_dir=""
if [[ -e "${backup_dir}" ]]; then
  rm -rf "${backup_dir}"
fi
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
