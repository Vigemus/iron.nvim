#!/usr/bin/env bash

set -euo pipefail

VERSION="${NVIM_TAG:-stable}"

curl -fsSL \
    "https://github.com/neovim/neovim/releases/download/${VERSION}/nvim-linux-x86_64.appimage" \
    -o nvim.appimage

chmod +x nvim.appimage

./nvim.appimage --appimage-extract >/dev/null

mkdir -p "$HOME/.local/share/nvim"
rm -rf "$HOME/.local/share/nvim/appimage"
mv squashfs-root "$HOME/.local/share/nvim/appimage"

mkdir -p "$HOME/.local/bin"
ln -sf \
    "$HOME/.local/share/nvim/appimage/AppRun" \
    "$HOME/.local/bin/nvim"

echo "$HOME/.local/bin" >> "$GITHUB_PATH"

nvim --version
