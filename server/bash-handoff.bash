# Sourced from Bash startup files. Leave noninteractive commands in Bash.
case $- in
  *i*) ;;
  *) return ;;
esac
if [[ -n ${DOTFILES_STAY_BASH:-} || -n ${DOTFILES_ZSH_SESSION:-} ]]; then
  return
fi

if type -P zsh >/dev/null 2>&1; then
  dotfiles_zsh="$(type -P zsh)"
elif [[ -x "$HOME/.local/bin/zsh" ]]; then
  dotfiles_zsh="$HOME/.local/bin/zsh"
else
  return
fi
export DOTFILES_ZSH_SESSION=1
exec "$dotfiles_zsh" -l
