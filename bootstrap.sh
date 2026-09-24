#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
case "$(uname -s):${1:-}" in
  Darwin:|Darwin:mac) profile=mac ;;
  Linux:wsl|Linux:server) profile="$1" ;;
  *)
    echo "Usage: ./bootstrap.sh [mac|wsl|server] (profile required on Linux)" >&2
    exit 2
    ;;
esac
if [[ $# -gt 0 ]]; then shift; fi
if [[ "$profile" != server && $# -gt 0 ]]; then
  echo "Unexpected arguments for $profile." >&2
  exit 2
fi
exec bash "$DIR/$profile/bootstrap.sh" "$@"
