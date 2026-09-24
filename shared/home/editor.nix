{ config, pkgs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in
{
  home.packages = [ pkgs.neovim ];
  home.sessionVariables.EDITOR = "nvim";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/shared/nvim";
}
