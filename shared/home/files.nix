{ config, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  entries = builtins.filter (line: line != "")
    (lib.splitString "\n" (builtins.readFile ../config-links.tsv));
in
{
  # The no-Nix server consumes the same manifest via link-shared-config.sh.
  home.file = builtins.listToAttrs (map (line:
    let fields = lib.splitString "\t" line;
    in {
      name = builtins.elemAt fields 1;
      value.source = config.lib.file.mkOutOfStoreSymlink
        "${dotfiles}/${builtins.elemAt fields 0}";
    }
  ) entries);
}
