#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
case "${1:-}" in
  ""|--check) ;;
  *) echo "Usage: link-shared-config.sh [--check]" >&2; exit 2 ;;
esac

# Check every target before creating any links.
while IFS=$'\t' read -r source_relative target_relative; do
  [[ -n "$source_relative" ]] || continue
  bash "$repo/shared/scripts/link-file.sh" "$repo/$source_relative" "$HOME/$target_relative" --check
done < "$repo/shared/config-links.tsv"

if [[ "${1:-}" != --check ]]; then
  while IFS=$'\t' read -r source_relative target_relative; do
    [[ -n "$source_relative" ]] || continue
    bash "$repo/shared/scripts/link-file.sh" "$repo/$source_relative" "$HOME/$target_relative"
  done < "$repo/shared/config-links.tsv"
fi
