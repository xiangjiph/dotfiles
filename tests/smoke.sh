#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-smoke.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

if "$repo/bootstrap.sh" >"$scratch/dispatch.out" 2>&1; then
  echo "Linux dispatch accepted a missing profile." >&2
  exit 1
fi
if "$repo/bootstrap.sh" mac >"$scratch/dispatch.out" 2>&1; then
  echo "Linux dispatch accepted the Mac profile." >&2
  exit 1
fi

export HOME="$scratch/home"
mkdir -p "$HOME"
bash "$repo/shared/scripts/link-repo.sh" "$repo"
bash "$repo/shared/scripts/link-repo.sh" "$repo"
[[ "$(readlink "$HOME/.dotfiles")" == "$repo" ]]

bash "$repo/shared/scripts/link-file.sh" "$repo/shared/nvim" "$HOME/.config/nvim"
bash "$repo/shared/scripts/link-file.sh" "$repo/shared/nvim" "$HOME/.config/nvim"
[[ "$(readlink "$HOME/.config/nvim")" == "$repo/shared/nvim" ]]

bash "$repo/server/ensure-bash-handoff.sh" >"$scratch/handoff.out"
bash "$repo/server/ensure-bash-handoff.sh" >>"$scratch/handoff.out"
[[ "$(grep -Fc 'server/bash-handoff.bash' "$HOME/.bashrc")" == 1 ]]
[[ "$(grep -Fc 'server/bash-handoff.bash' "$HOME/.profile")" == 1 ]]
bash -c '. "$1/server/bash-handoff.bash"; echo noninteractive-ok' bash "$repo" |
  grep -Fxq noninteractive-ok

mkdir -p "$scratch/bin"
ln -s "$repo/tests/fixtures/fake-zsh" "$scratch/bin/zsh"
export PATH="$scratch/bin:$PATH"
bash -ic 'echo should-not-run' 2>/dev/null | grep -Fxq entered-zsh
DOTFILES_STAY_BASH=1 bash -ic 'echo bash-kept' 2>/dev/null | grep -Fxq bash-kept
DOTFILES_ZSH_SESSION=1 bash -ic 'echo bash-kept' 2>/dev/null | grep -Fxq bash-kept

echo "Shell dispatch, links, idempotency, interactive Zsh, and Bash fallback passed."
