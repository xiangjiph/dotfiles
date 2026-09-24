{ config, pkgs, user, homeDirectory, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  imports = [ ../shared/home/editor.nix ];

  home.username = user;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "24.11";
  home.packages = with pkgs; [ zsh ripgrep fd fzf jq ];
  programs.home-manager.enable = true;
  programs.zsh = {
    enable = true;
    initContent = ''
      source "${dotfiles}/shared/zsh/common.zsh"
    '';
  };

  # Keep Bash as the account shell; only interactive sessions enter Zsh.
  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $- == *i* && -z ''${DOTFILES_STAY_BASH:-} && -z ''${DOTFILES_ZSH_SESSION:-} && -x ${pkgs.zsh}/bin/zsh ]]; then
        export DOTFILES_ZSH_SESSION=1
        exec ${pkgs.zsh}/bin/zsh -l
      fi
    '';
  };
}
