#!/usr/bin/env bash
# Called only by the explicit Mac --migrate-from workflow.
set -euo pipefail

fail() { echo "$*" >&2; exit 1; }
[[ $# -eq 1 && -n "$1" ]] || fail 'Usage: mac/migrate.sh OLD_CHECKOUT'
[[ "$(uname -s)" == Darwin ]] || fail 'Checkout migration is supported only on macOS.'
[[ "$(id -u)" != 0 ]] || fail 'Run migration as your normal user; it requests sudo only for activation.'

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
old_repo="$(cd "$1" && pwd -P)"
link="$HOME/.dotfiles"
profile=/nix/var/nix/profiles/system
lock="$HOME/.dotfiles-migration.lock"
[[ "$old_repo" != "$repo" ]] || fail 'The old and new checkouts must differ.'
[[ -f "$old_repo/flake.nix" ]] || fail 'The old checkout has no flake.nix.'
[[ -L "$link" && -d "$link" ]] || fail "$link must be an existing symlink to the old checkout."
[[ "$(cd "$link" && pwd -P)" == "$old_repo" ]] || fail "$link does not point to the supplied old checkout."
old_target="$(readlink "$link")"
nix_bin="$(command -v nix)"
nix_env_bin="$(command -v nix-env)"
command -v sudo >/dev/null

mkdir "$lock" || fail "Migration lock already exists: $lock"
journal=
staging=
old_system=
new_system=
link_armed=0
profile_armed=0
completed=0

replace_link() {
  # Both paths are on the home filesystem. BSD mv -h replaces the symlink
  # itself rather than following its directory target; rename is atomic.
  ln -s "$1" "$staging/dotfiles"
  /bin/mv -fh "$staging/dotfiles" "$link"
}

cleanup() {
  local status=$?
  trap - EXIT
  trap '' HUP INT TERM
  set +e
  if [[ "$completed" == 0 && "$link_armed" == 1 ]]; then
    if [[ -L "$link" && "$(readlink "$link")" == "$repo" ]]; then
      replace_link "$old_target"
      if [[ $? == 0 ]]; then
        echo "Restored $link to its previous target." >&2
      else
        echo "Could not restore $link; use the recovery record below." >&2
      fi
    elif [[ ! -L "$link" || "$(readlink "$link")" != "$old_target" ]]; then
      echo "$link changed independently; refusing to overwrite it during recovery." >&2
    fi
  fi
  if [[ "$completed" == 0 && "$profile_armed" == 1 ]]; then
    local current_system
    current_system="$("$nix_bin" path-info "$profile")"
    if [[ "$current_system" == "$new_system" ]]; then
      sudo -n "$nix_env_bin" -p "$profile" --set "$old_system" ||
        echo 'Could not restore the system profile pointer.' >&2
    elif [[ "$current_system" != "$old_system" ]]; then
      echo 'The system profile changed independently; refusing to overwrite it during recovery.' >&2
    fi
    echo 'Activation may have partially applied. To reactivate the previous system after restoring .dotfiles:' >&2
    printf '  sudo %q activate\n' "$old_system/sw/bin/darwin-rebuild" >&2
    echo 'Homebrew changes may require separate recovery.' >&2
  fi
  if [[ -n "$journal" ]]; then
    echo "Migration record and retained build: $journal" >&2
  fi
  if [[ -n "$staging" ]]; then
    # Remove only our unconsumed temporary symlink and empty directory.
    [[ ! -L "$staging/dotfiles" ]] || unlink "$staging/dotfiles"
    rmdir "$staging"
  fi
  rmdir "$lock"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

old_generation="$(readlink "$profile")"
old_system="$("$nix_bin" path-info "$profile")"
[[ -x "$old_system/sw/bin/darwin-rebuild" ]] || fail 'Cannot locate the previous system activation tool.'
mkdir -p "$HOME/.local/state/dotfiles/migrations"
journal="$(mktemp -d "$HOME/.local/state/dotfiles/migrations/migration.XXXXXX")"
staging="$(mktemp -d "$HOME/.dotfiles-migrate.XXXXXX")"
printf '%s\n' "$old_target" > "$journal/old-link-target"
printf '%s\n' "$old_repo" > "$journal/old-checkout"
printf '%s\n' "$old_generation" > "$journal/old-generation"
printf '%s\n' "$old_system" > "$journal/old-system"
printf '%s\n' "$repo" > "$journal/new-checkout"

echo 'Building the new system while the existing .dotfiles link remains active...'
"$nix_bin" build --no-write-lock-file --out-link "$journal/new-system" \
  "path:$repo#darwinConfigurations.mac.system"
new_system="$("$nix_bin" path-info "$journal/new-system")"
[[ -x "$new_system/sw/bin/darwin-rebuild" ]] || fail 'The build has no darwin-rebuild activation tool.'
printf '%s\n' "$new_system" > "$journal/new-system-path"

# Authenticate before changing links, then use noninteractive sudo below.
sudo -v
[[ -L "$link" && "$(readlink "$link")" == "$old_target" ]] || fail '.dotfiles changed during the build; migration cancelled.'
[[ "$(cd "$link" && pwd -P)" == "$old_repo" ]] || fail 'The old checkout moved during the build; migration cancelled.'
[[ "$(readlink "$profile")" == "$old_generation" && "$("$nix_bin" path-info "$profile")" == "$old_system" ]] ||
  fail 'The system generation changed during the build; migration cancelled.'

# Arm recovery before each change so signals cannot leave an untracked change.
link_armed=1
replace_link "$repo"
profile_armed=1
sudo -n "$nix_env_bin" -p "$profile" --set "$new_system"
# `activate` uses this exact build and does not re-evaluate the checkout.
sudo -n "$new_system/sw/bin/darwin-rebuild" activate
completed=1
printf '%s\n' complete > "$journal/status"
echo 'Migration complete. Future changes use ./rebuild.sh.'
