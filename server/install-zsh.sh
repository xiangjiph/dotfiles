#!/usr/bin/env bash
set -euo pipefail

if command -v zsh >/dev/null 2>&1; then
  echo "Using existing Zsh: $(command -v zsh)"
  exit 0
fi

version=5.9.2
expected_sha=36fa734374b44783582cec09bcd67822e2f992c779ec1624ab5596df078d2f81
prefix="$HOME/.local/opt/zsh/$version"
if [[ -x "$prefix/bin/zsh" ]]; then
  echo "Using previously built Zsh: $prefix/bin/zsh"
else
  if [[ -e "$prefix" ]]; then
    echo "$prefix exists but has no usable Zsh; inspect it before retrying." >&2
    exit 1
  fi
  for tool in curl tar xz sha256sum make cc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Cannot build Zsh without $tool. Bash remains available." >&2
      exit 1
    fi
  done
  build_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-zsh.XXXXXX")"
  trap 'rm -rf -- "$build_dir"' EXIT
  archive="$build_dir/zsh-$version.tar.xz"
  curl --proto '=https' --tlsv1.2 -sSfL "https://www.zsh.org/pub/zsh-$version.tar.xz" -o "$archive"
  printf '%s  %s\n' "$expected_sha" "$archive" | sha256sum -c -
  tar -xJf "$archive" -C "$build_dir"
  mkdir -p "$(dirname "$prefix")"
  (
    cd "$build_dir/zsh-$version"
    ./configure --prefix="$prefix"
    make -j2
    make install
  )
fi

mkdir -p "$HOME/.local/bin"
if [[ ! -e "$HOME/.local/bin/zsh" && ! -L "$HOME/.local/bin/zsh" ]]; then
  ln -s "$prefix/bin/zsh" "$HOME/.local/bin/zsh"
elif [[ "$(readlink "$HOME/.local/bin/zsh" 2>/dev/null || true)" != "$prefix/bin/zsh" ]]; then
  echo "$HOME/.local/bin/zsh already exists; move it before continuing." >&2
  exit 1
fi
"$HOME/.local/bin/zsh" --version
