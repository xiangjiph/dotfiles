# Dotfiles

This repo has three profiles. The Mac profile keeps the original nix-darwin setup. WSL uses standalone Home Manager for a development shell. The server profile installs only Zsh and links editor/shell config by default; it needs no root or Nix if the machine can build Zsh from source.

## Commands

| Machine | First setup | Apply later edits |
| --- | --- | --- |
| Mac | `./bootstrap.sh` | `./rebuild.sh` |
| Ubuntu in WSL | `./bootstrap.sh wsl` | `./rebuild.sh wsl` |
| Ubuntu server without Nix | `./bootstrap.sh server` | `./rebuild.sh server` |
| Server with usable Nix, optional | `./bootstrap.sh server --home-manager` | `./rebuild.sh server --home-manager` |

The root scripts dispatch to the corresponding scripts in `mac/`, `wsl/`, or `server/`. You can invoke a subfolder script directly. On Linux, the root scripts require an explicit profile. Run them from the clone on the machine being configured. They create `~/.dotfiles` pointing at this clone; an existing real directory or different symlink there causes a safe failure.

### Mac

The Mac scripts retain the original Determinate Nix and `darwin-rebuild` workflow. The flake output is still `#mac` and the pinned Mac inputs are unchanged. The first bootstrap may offer to rewrite the configured Mac username in `flake.nix`, as before. Existing Home Manager collisions get `.backup` suffixes under the Mac module.

### WSL

Run from the Linux filesystem, such as a checkout under `$HOME`, with an account that can use `sudo` once if Nix is absent. Bootstrap installs single-user Nix when needed, then the pinned Home Manager configuration supplies Zsh, Neovim, ripgrep, fd, fzf, jq, tldr, lazygit, and Starship. Existing files that Home Manager takes over receive a timestamped `dotfiles-backup-*` suffix. Open a new terminal after bootstrap.

Interactive Bash enters Zsh. Bash remains the account shell and runs noninteractive commands; to stay in Bash interactively, run `DOTFILES_STAY_BASH=1 bash`. No `chsh` or WSL systemd change is required. WezTerm and fonts belong to the host terminal setup and are not installed into WSL by this profile.

### Server

The default server profile uses an existing Zsh if available. Otherwise it builds Zsh 5.9.2 from the official source archive, checks the pinned SHA-256 hash, and installs under `$HOME/.local`. Building requires `curl`, `tar`, `xz`, `sha256sum`, `make`, `cc`, and usable terminal development libraries; the script reports a missing prerequisite. It never invokes `sudo` or changes the account's login shell. It links `~/.zshrc` and `~/.config/nvim` to this repo, and adds a guarded handoff to Bash startup files so interactive logins enter Zsh. Existing `.bashrc` and login startup files are backed up before the handoff line is added. Existing `.zshrc` and Neovim configs must be moved manually before bootstrap; nothing replaces them silently.

Noninteractive SSH commands, scripts, and file transfers stay in Bash. To open an interactive Bash session, use `DOTFILES_STAY_BASH=1 bash`; Bash launched from the Zsh session also stays in Bash. If Neovim is not installed, the config link is staged but `EDITOR` is left alone. The optional Home Manager server profile requires a working Nix installation for the account and installs a small headless tool set, including Zsh.

## Changes and recovery

Editor settings live in `shared/nvim/`; edit them here and the out-of-store links see changes immediately. Mac and WSL package/shell changes require their respective rebuild commands. The default server rebuild checks its links and handoff and installs Zsh only if still missing. Home Manager generations can be listed and rolled back with `home-manager generations` and `home-manager switch --rollback` for standalone profiles. To undo the default server setup, remove only the links that point into this repo and remove the marked handoff lines from `.bashrc` and the login startup file; the timestamped backups show the previous contents. Do not delete unrelated files.

For architecture and the cross-OS change protocol, see [agent/ARCHITECTURE.md](agent/ARCHITECTURE.md).
