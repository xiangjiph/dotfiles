# Pure module-wiring checks: no flake fetching, builds, or activation.
let
  lib.splitString = separator: value:
    builtins.filter builtins.isString (builtins.split separator value);
  pkgs = builtins.listToAttrs (map (name: { inherit name; value = name; })
    [ "neovim" "git" "ripgrep" "tldr" "fd" "fzf" "jq" "lazygit" "zsh" ])
    // { nerd-fonts.hack = "hack-font"; };
  check = profile: homeDirectory:
    let
      config = {
        home = { inherit homeDirectory; };
        lib.file.mkOutOfStoreSymlink = path: path;
      };
      args = { inherit config pkgs lib homeDirectory; user = "test-user"; };
      root = import profile args;
      modules = [ root ] ++ map (path: import path args) root.imports;
      files = builtins.foldl' (all: module: all // (module.home.file or {})) {} modules;
      packages = builtins.concatMap (module: module.home.packages or []) modules;
      expected = {
        ".config/nvim" = "shared/nvim";
        ".config/herdr" = "shared/herdr";
        ".claude/settings.json" = "shared/claude/settings.json";
        ".claude/CLAUDE.md" = "shared/agents/AGENTS.md";
        ".codex/AGENTS.md" = "shared/agents/AGENTS.md";
        ".config/opencode/AGENTS.md" = "shared/agents/AGENTS.md";
      };
    in
      assert builtins.all (target:
        files.${target}.source == "${homeDirectory}/.dotfiles/${expected.${target}}"
      ) (builtins.attrNames expected);
      assert builtins.elem "git" packages && builtins.elem "neovim" packages;
      assert builtins.any (module: (module.home.sessionVariables.EDITOR or null) == "nvim") modules;
      assert !(files ? ".config/nvim-local");
      "shared links, editor packages, and EDITOR passed";
in
{
  mac = check ../mac/home.nix "/Users/test-user";
  wsl = check ../wsl/home.nix "/home/test-user";
  server = check ../server/home.nix "/home/test-user";
}
