#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ~/.config
ln -sf "$REPO_DIR/.tmux.conf" ~/.tmux.conf
ln -sf "$REPO_DIR/.bash_profile" ~/.bash_profile
ln -sfn "$REPO_DIR/scripts" ~/.config/scripts
ln -sfn "$REPO_DIR/nvim" ~/.config/nvim
ln -sf "$REPO_DIR/.gitconfig" ~/.gitconfig
ln -sf "$REPO_DIR/.vifmrc" ~/.vifmrc
