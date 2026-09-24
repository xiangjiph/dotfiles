#!/usr/bin/env bash 
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
case "${1:-}" in
  "")
    if [[ $# -ne 0 ]]; then
      echo "Usage: mac/rebuild.sh [--migrate-from OLD_CHECKOUT]" >&2
      exit 2
    fi
    ;;
  --migrate-from)
    if [[ $# -ne 2 || -z "$2" ]]; then
      echo "Usage: mac/rebuild.sh --migrate-from OLD_CHECKOUT" >&2
      exit 2
    fi
    exec bash "$DIR/mac/migrate.sh" "$2"
    ;;
  *) echo "Usage: mac/rebuild.sh [--migrate-from OLD_CHECKOUT]" >&2; exit 2 ;;
esac
if [[ -e "$HOME/.dotfiles-migration.lock" ]]; then
  echo "A migration lock exists at $HOME/.dotfiles-migration.lock; resolve that migration first." >&2
  exit 1
fi
bash "$DIR/shared/scripts/link-repo.sh" "$DIR"
exec sudo darwin-rebuild switch --flake "path:$DIR#mac"
