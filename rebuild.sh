#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
case "$(uname -s):${1:-}" in
  Darwin:|Darwin:mac|Darwin:--migrate-from) profile=mac ;;
  Linux:wsl|Linux:server) profile="$1" ;;
  *)
    echo "Usage: ./rebuild.sh [mac|wsl|server] [profile options] (profile required on Linux)" >&2
    exit 2
    ;;
esac
if [[ "${1:-}" == "$profile" ]]; then shift; fi
if [[ "$profile" == wsl && $# -gt 0 ]]; then
  echo "Unexpected arguments for $profile." >&2
  exit 2
fi
exec bash "$DIR/$profile/rebuild.sh" "$@"
