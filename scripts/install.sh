#!/usr/bin/env bash
set -euo pipefail

REPO="opencat/opencat"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)  os="linux" ;;
        Darwin) os="darwin" ;;
        *)      echo "Unsupported OS: $os" >&2; exit 1 ;;
    esac

    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)             echo "Unsupported architecture: $arch" >&2; exit 1 ;;
    esac

    echo "${os}-${arch}"
}

main() {
    local platform version download_url tmp_dir

    platform="$(detect_platform)"
    echo "Detected platform: ${platform}"

    # Get latest release
    version="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"
    echo "Latest version: ${version}"

    download_url="https://github.com/${REPO}/releases/download/${version}/opencat-${platform}"

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    echo "Downloading opencat ${version}..."
    curl -fsSL -o "${tmp_dir}/opencat" "${download_url}"
    chmod +x "${tmp_dir}/opencat"

    echo "Installing to ${INSTALL_DIR}/opencat..."
    if [ -w "$INSTALL_DIR" ]; then
        mv "${tmp_dir}/opencat" "${INSTALL_DIR}/opencat"
    else
        sudo mv "${tmp_dir}/opencat" "${INSTALL_DIR}/opencat"
    fi

    echo "opencat ${version} installed successfully!"
    echo "Run 'opencat serve' to start the server."
}

main "$@"
