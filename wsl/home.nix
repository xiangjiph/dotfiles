{ pkgs, user, homeDirectory, ... }:

{
  imports = [ ../shared/home/files.nix ../shared/home/editor.nix ../shared/home/zsh.nix ];

  home.username = user;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "24.11";
  home.packages = with pkgs; [ ripgrep tldr fd fzf jq lazygit ];
  programs.home-manager.enable = true;

  programs.zsh.shellAliases = {
    add = "git add .";
    push = "git push";
    pull = "git pull";
  };

  # Bash stays the account login shell and remains available from Zsh.
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
