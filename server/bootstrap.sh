#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$DIR/shared/scripts/linux-env.sh"
dotfiles_linux_env
bash "$DIR/shared/scripts/link-repo.sh" "$DIR"

case "${1:-}" in
  "")
    bash "$DIR/shared/scripts/link-file.sh" "$DIR/server/zshrc" "$HOME/.zshrc" --check
    bash "$DIR/shared/scripts/link-file.sh" "$DIR/shared/nvim" "$HOME/.config/nvim" --check
    bash "$DIR/server/ensure-bash-handoff.sh" --check
    bash "$DIR/server/install-zsh.sh"
    bash "$DIR/shared/scripts/link-file.sh" "$DIR/server/zshrc" "$HOME/.zshrc"
    bash "$DIR/shared/scripts/link-file.sh" "$DIR/shared/nvim" "$HOME/.config/nvim"
    bash "$DIR/server/ensure-bash-handoff.sh"
    echo "Server setup complete. New interactive Bash sessions will enter Zsh."
    ;;
  --home-manager)
    if ! command -v nix >/dev/null 2>&1; then
      echo "Nix is unavailable. Use the default server profile or ask an administrator to provide Nix." >&2
      exit 1
    fi
    backup_ext="dotfiles-backup-$(date +%Y%m%d%H%M%S)"
    echo "Existing home files managed by Home Manager will be backed up with extension $backup_ext."
    nix run github:nix-community/home-manager/release-26.05 -- \
      switch --flake "path:$DIR#server-$DOTFILES_ARCH" --impure -b "$backup_ext"
    ;;
  *) echo "Usage: server/bootstrap.sh [--home-manager]" >&2; exit 2 ;;
esac
