#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
case "${1:-}" in
  "") exec bash "$DIR/server/bootstrap.sh" ;;
  --home-manager)
    source "$DIR/shared/scripts/linux-env.sh"
    dotfiles_linux_env
    bash "$DIR/shared/scripts/link-repo.sh" "$DIR"
    if ! command -v home-manager >/dev/null 2>&1; then
      echo "home-manager is unavailable. Run server/bootstrap.sh --home-manager first." >&2
      exit 1
    fi
    exec home-manager switch --flake "path:$DIR#server-$DOTFILES_ARCH" --impure
    ;;
  *) echo "Usage: server/rebuild.sh [--home-manager]" >&2; exit 2 ;;
esac
