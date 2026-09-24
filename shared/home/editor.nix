{ pkgs, ... }:

{
  # Git is needed by lazy.nvim and the shared editor's Git plugins.
  home.packages = [ pkgs.neovim pkgs.git ];
  home.sessionVariables.EDITOR = "nvim";
}
