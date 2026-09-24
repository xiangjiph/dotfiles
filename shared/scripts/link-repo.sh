#!/usr/bin/env bash
set -euo pipefail

repo_dir="${1:?repository path required}"
link="$HOME/.dotfiles"
if [[ -L "$link" ]]; then
  if [[ "$(readlink "$link")" == "$repo_dir" ]]; then
    exit 0
  fi
  echo "$link already points somewhere else; move it before continuing." >&2
  exit 1
fi
if [[ -e "$link" ]]; then
  echo "$link already exists; move it before continuing." >&2
  exit 1
fi
ln -s "$repo_dir" "$link"
