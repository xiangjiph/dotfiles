#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$DIR/shared/scripts/linux-env.sh"
dotfiles_linux_env
bash "$DIR/shared/scripts/link-repo.sh" "$DIR"

if ! command -v nix >/dev/null 2>&1; then
  echo "Installing single-user Nix for WSL. This may ask for sudo once to create /nix."
  curl --proto '=https' --tlsv1.2 -sSfL https://nixos.org/nix/install |
    sh -s -- --no-daemon
  # shellcheck disable=SC1091
  source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not on PATH. Start a new terminal and retry." >&2
  exit 1
fi

echo "Existing home files managed by Home Manager will be backed up with a timestamp."
backup_ext="dotfiles-backup-$(date +%Y%m%d%H%M%S)"
nix run github:nix-community/home-manager/release-26.05 -- \
  switch --flake "path:$DIR#wsl-$DOTFILES_ARCH" --impure -b "$backup_ext"
echo "WSL setup complete. Open a new terminal; Bash remains available with DOTFILES_STAY_BASH=1 bash."
