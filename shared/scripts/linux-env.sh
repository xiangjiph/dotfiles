#!/usr/bin/env bash

dotfiles_linux_env() {
  if [[ "$(uname -s)" != Linux ]]; then
    echo "This profile requires Linux." >&2
    return 1
  fi
  local actual_user account_entry account_home
  actual_user="$(id -un)"
  if ! account_entry="$(getent passwd "$actual_user")"; then
    echo "Cannot look up the current account with getent." >&2
    return 1
  fi
  account_home="${account_entry#*:*:*:*:*:}"
  account_home="${account_home%%:*}"
  if [[ -z "$account_home" || "$HOME" != "$account_home" || "$HOME" != /* ]]; then
    echo "HOME does not match the account home directory ($account_home)." >&2
    return 1
  fi
  export USER="$actual_user"
  case "$(uname -m)" in
    x86_64) DOTFILES_ARCH=x86_64 ;;
    aarch64|arm64) DOTFILES_ARCH=aarch64 ;;
    *) echo "Unsupported Linux architecture: $(uname -m)" >&2; return 1 ;;
  esac
  export DOTFILES_ARCH
  export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'
}
