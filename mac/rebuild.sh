#!/usr/bin/env bash 
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash "$DIR/shared/scripts/link-repo.sh" "$DIR"
exec sudo darwin-rebuild switch --flake "path:$DIR#mac"
