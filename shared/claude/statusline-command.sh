#!/usr/bin/env bash
# Claude Code status line: model name and context usage.
set -euo pipefail

# The no-Nix server profile does not install jq.
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
model=$(jq -r '.model.display_name // "unknown"' <<< "$input")
used=$(jq -r '.context_window.used_percentage // empty' <<< "$input")

if [[ -n "$used" ]]; then
  printf '\033[2m%s | Context: %.0f%% used\033[0m' "$model" "$used"
else
  printf '\033[2m%s\033[0m' "$model"
fi
