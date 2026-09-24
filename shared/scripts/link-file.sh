#!/usr/bin/env bash
set -euo pipefail

source_path="${1:?source path required}"
target_path="${2:?target path required}"
if [[ -L "$target_path" ]]; then
  if [[ "$(readlink "$target_path")" == "$source_path" ]]; then
    exit 0
  fi
  echo "$target_path is already a different symlink; move it before continuing." >&2
  exit 1
fi
if [[ -e "$target_path" ]]; then
  echo "$target_path already exists; move it before continuing." >&2
  exit 1
fi
if [[ "${3:-}" == --check ]]; then
  exit 0
fi
mkdir -p "$(dirname "$target_path")"
ln -s "$source_path" "$target_path"
