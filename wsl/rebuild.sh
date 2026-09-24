#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$DIR/shared/scripts/linux-env.sh"
dotfiles_linux_env
bash "$DIR/shared/scripts/link-repo.sh" "$DIR"

if ! command -v home-manager >/dev/null 2>&1; then
  echo "home-manager is not on PATH. Run ./bootstrap.sh wsl or open a new terminal." >&2
  exit 1
fi
home-manager switch --flake "path:$DIR#wsl-$DOTFILES_ARCH" --impure
