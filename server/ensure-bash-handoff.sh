#!/usr/bin/env bash
set -euo pipefail

line='if [ -n "${BASH_VERSION:-}" ] && [ -r "$HOME/.dotfiles/server/bash-handoff.bash" ]; then . "$HOME/.dotfiles/server/bash-handoff.bash"; fi'

append_once() {
  local file="$1"
  if [[ -L "$file" ]]; then
    echo "$file is a symlink; add the handoff line to its source manually." >&2
    return 1
  fi
  if [[ -e "$file" ]] && grep -Fxq "$line" "$file"; then
    return 0
  fi
  if [[ -e "$file" ]]; then
    local backup="$file.dotfiles-backup-$(date +%Y%m%d%H%M%S)-$$"
    cp -p "$file" "$backup"
    echo "Backed up $file to $backup"
  fi
  printf '\n# Enter Zsh for interactive dotfiles sessions; set DOTFILES_STAY_BASH=1 to stay in Bash.\n%s\n' "$line" >> "$file"
}

if [[ -e "$HOME/.bash_profile" || -L "$HOME/.bash_profile" ]]; then
  login_file="$HOME/.bash_profile"
elif [[ -e "$HOME/.bash_login" || -L "$HOME/.bash_login" ]]; then
  login_file="$HOME/.bash_login"
else
  login_file="$HOME/.profile"
fi
for file in "$HOME/.bashrc" "$login_file"; do
  if [[ -L "$file" ]]; then
    echo "$file is a symlink; add the handoff line to its source manually." >&2
    exit 1
  fi
  if [[ -e "$file" && ! -w "$file" ]]; then
    echo "$file is not writable; no handoff files were changed." >&2
    exit 1
  fi
done
if [[ "${1:-}" == --check ]]; then
  exit 0
fi
append_once "$HOME/.bashrc"
append_once "$login_file"
