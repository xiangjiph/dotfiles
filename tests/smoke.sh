#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-smoke.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

# Never dispatch a valid setup on the host running this test.
if "$repo/bootstrap.sh" invalid-profile >"$scratch/dispatch.out" 2>&1; then
  echo "Dispatch accepted an invalid profile." >&2
  exit 1
fi

export HOME="$scratch/home"
mkdir -p "$HOME"
bash "$repo/shared/scripts/link-repo.sh" "$repo"
bash "$repo/shared/scripts/link-repo.sh" "$repo"
[[ "$(readlink "$HOME/.dotfiles")" == "$repo" ]]

# A conflict late in the manifest must prevent all config links.
mkdir -p "$HOME/.config/opencode"
printf '%s\n' 'preserve me' > "$HOME/.config/opencode/AGENTS.md"
if bash "$repo/shared/scripts/link-shared-config.sh" >"$scratch/conflict.out" 2>&1; then
  echo "Shared config links accepted an existing user file." >&2
  exit 1
fi
[[ ! -e "$HOME/.config/nvim" ]]
[[ "$(cat "$HOME/.config/opencode/AGENTS.md")" == 'preserve me' ]]
mv "$HOME/.config/opencode/AGENTS.md" "$scratch/preserved-AGENTS.md"
bash "$repo/shared/scripts/link-shared-config.sh" --check
[[ ! -e "$HOME/.config/nvim" ]]
bash "$repo/shared/scripts/link-shared-config.sh"
bash "$repo/shared/scripts/link-shared-config.sh"
while IFS=$'\t' read -r source_relative target_relative; do
  [[ "$(readlink "$HOME/$target_relative")" == "$repo/$source_relative" ]]
  [[ -e "$HOME/$target_relative" ]]
done < "$repo/shared/config-links.tsv"

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
