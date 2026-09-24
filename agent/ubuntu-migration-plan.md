# Plan: preserve macOS, add WSL and server profiles with Zsh

Date: 2026-09-23. Implemented; see [ARCHITECTURE.md](ARCHITECTURE.md) and the root README for the current layout and commands. This file records the original migration rationale.

## Recommendation

Do **not** install the whole Mac setup on WSL or a server. The Mac configuration manages OS defaults, Homebrew applications, a graphical terminal, fonts, and an interactive shell. WSL is a second development workstation, so its useful overlap is command-line tools, editor settings, and Zsh. A remote server should have a small CLI setup with Zsh installed in user space when necessary. Bash remains installed and usable everywhere. Installing Nix solely for a prompt, Zsh, and editor config on a restricted server is usually not worth the setup and maintenance cost.

| Environment | Default scope | Deployment |
| --- | --- | --- |
| Mac | Existing full workstation setup, including Zsh | Existing nix-darwin + Home Manager and the `#mac` output. |
| Ubuntu under WSL | Development CLI and editor: ripgrep, fd, fzf, jq, Neovim, optionally tldr/lazygit, plus Zsh and shell settings | Standalone Home Manager installs and configures Zsh and the CLI tools. Keep Bash configured and available. No macOS settings, Homebrew, WezTerm package, Nerd Font, or Linux system administration. The terminal and font normally belong to the Windows host. |
| Remote Ubuntu server | Zsh, Neovim config, and a few chosen shell conveniences; use existing server tools | A user-owned setup installs Zsh when absent and links the configs. Keep system Bash as the login shell and as a script/interactive fallback. No root or system-file changes. |
| Long-lived personal server with usable Nix | Optional headless CLI profile | Standalone Home Manager can install Zsh and selected CLI tools if Nix already works for the account. This is an opt-in extension of the server profile. |

The no-root server case matters: standard Nix needs a usable `/nix` store. If the server lacks one, an administrator normally has to provision it. A user-local Zsh source build is the planned alternative, but it needs a compiler, `make`, and appropriate development headers/libraries; if those are absent, the script must report that prerequisite rather than claim success. `nix-portable` is not a prerequisite. See [Nix installation](https://nix.dev/manual/nix/2.19/installation/installing-binary), [Home Manager standalone requirements](https://nix-community.github.io/home-manager/installation/standalone.html), and [Zsh's installation instructions](https://github.com/zsh-users/zsh/blob/master/INSTALL).

## Repo findings

- `flake.nix` has only `darwinConfigurations.mac`, a fixed `xiangji` user, a Darwin Nixpkgs pin, nix-darwin, Home Manager, and nix-homebrew.
- `configuration.nix` is Mac-only: `aarch64-darwin`, `/Users/...`, system defaults, and Homebrew apps/casks (`herdr`, WezTerm, Claude Code, Codex).
- `home.nix` mixes reusable CLI/editor settings with Mac-specific home paths, a Nerd Font, a WezTerm link, and Zsh configuration. It uses `home.stateVersion = "24.11"`, which should remain unchanged during the split.
- The current root `bootstrap.sh` uses macOS `sed -i ''`, installs Determinate Nix, and calls `sudo darwin-rebuild`; root `rebuild.sh` also always calls `sudo darwin-rebuild`. Move their implementations to `mac/` and replace the root scripts with dispatchers.
- The Neovim and WezTerm links rely on `~/.dotfiles` pointing at the checkout. A new script must detect an existing real `~/.dotfiles` directory or existing config files before changing links.

## Repository layout and command contract

```text
bootstrap.sh, rebuild.sh       # root dispatchers only
flake.nix, flake.lock           # root flake and shared pins
shared/nvim/                    # reusable Neovim files
shared/home/editor.nix          # Home Manager editor settings
shared/zsh/                     # reusable Zsh config, with optional features guarded
mac/bootstrap.sh, rebuild.sh, configuration.nix, home.nix, wezterm/
wsl/bootstrap.sh, rebuild.sh, home.nix
server/bootstrap.sh, rebuild.sh, home.nix  # home.nix is opt-in with existing Nix
```

The root scripts **call the matching subfolder script**; they contain only argument/OS validation and dispatch. They are not Mac-only implementations. `./bootstrap.sh` and `./rebuild.sh` with no argument retain Mac behavior on Darwin. On Linux, require an explicit profile: `./bootstrap.sh wsl`, `./rebuild.sh wsl`, `./bootstrap.sh server`, or `./rebuild.sh server`. Direct calls such as `./mac/rebuild.sh` and `./server/bootstrap.sh` also work. Never infer “server” from `uname`, because both WSL and servers are Linux. The root flake retains `darwinConfigurations.mac` and points it at `mac/`; Linux Home Manager outputs point at `wsl/` and optionally `server/`.

## Implementation sequence

1. **Freeze the Mac contract.** Record the current `#mac` evaluation and relevant outputs. Keep its host label, input revisions, system defaults, and Homebrew packages. Move the Mac script bodies to `mac/`, update their repo-root calculation and flake paths, then add root dispatchers that preserve the existing no-argument Mac commands. Compare the Mac evaluation after the refactor.

2. **Extract only truly shared settings.** Put the Neovim files in `shared/nvim/`, and share their Home Manager link and `EDITOR` setting through a small module. Keep Mac home path, WezTerm, font, and Mac-specific behavior in `mac/`. Put common Zsh settings in `shared/zsh/`, while allowing WSL and server to skip plugins or prompt tools that are unavailable. Keep package lists per profile so the server does not inherit the workstation package set or the current `add`, `push`, and `pull` aliases automatically. Test clipboard behavior over WSL and SSH before assigning a Linux clipboard provider.

3. **Add a WSL workstation profile.** Use `home-manager.lib.homeManagerConfiguration` for `x86_64-linux`, with a Linux Nixpkgs 26.05 pin and matching Home Manager release separate from the existing Darwin pins. Install the CLI set above and Zsh; enable Home Manager's Zsh configuration and Bash configuration so both shells work. Make interactive terminals start Zsh, preferably through the terminal launch command or a guarded interactive Bash handoff. Do not require `chsh` or change the account's login shell. Take `USER` and `HOME` for the Linux profile through a validated `--impure` evaluation rather than editing tracked `flake.nix` for each machine. Rebuild as the normal user. WSL does not need systemd just to run Home Manager; see [standalone flake setup](https://nix-community.github.io/home-manager/nix-flakes/standalone.html), [Zsh options](https://nix-community.github.io/home-manager/options/home-manager/programs/zsh.html), and [WSL systemd documentation](https://learn.microsoft.com/en-us/windows/wsl/systemd).

4. **Add a server route with no Nix dependency.** Detect an existing usable `zsh` first. If absent, install a pinned Zsh release under `$HOME/.local/opt/zsh/<version>` and expose it through `$HOME/.local/bin/zsh`, verifying its source checksum and build prerequisites before installation. No `sudo`, `chsh`, or `/etc/shells` edits. Link a minimal `~/.zshrc` and `~/.config/nvim` to this repo, checking existing targets and requiring an explicit backup choice for conflicts. Add a guarded, user-owned Bash startup handoff for interactive SSH/terminal sessions only. Use an exported session marker to prevent a Bash-from-Zsh loop, and support `DOTFILES_STAY_BASH=1` to bypass the handoff; noninteractive SSH commands, scripts, and file transfers must stay in Bash. Keep repeated bootstrap/rebuild runs harmless. If Neovim is absent, stage its config but do not set `EDITOR=nvim`. If source-build prerequisites are missing, report the missing pieces and leave Bash usable; an administrator-provided Zsh or a compatible user-supplied binary is then required.

5. **Offer an opt-in Home Manager server profile.** If the account can run Nix builds, expose a headless profile with Zsh and only Neovim, ripgrep, fd, fzf, and jq as needed. Exclude fonts, terminal GUI, Homebrew, and machine services. Reuse the same username/home validation as WSL and the same guarded interactive-shell behavior as the no-Nix route. If there is no usable Nix, use the source/local installation route; do not make `nix-portable` a required implementation milestone.

6. **Verify and document.** Evaluate/build the Mac configuration and WSL Home Manager activation package before switching. Test root dispatch and direct subfolder calls, WSL first install and second rebuild, Zsh startup, Bash fallback, PATH, and Neovim link updates. Test server setup in a disposable non-root account with existing file conflicts and repeated runs; verify interactive SSH enters Zsh, while `ssh host 'echo ok'`, scripts, and file transfers remain unaffected. Test optional server Home Manager only on a host with working Nix. Publish exact commands and rollback steps for each platform in a tracked README.

## Acceptance criteria

- Fresh and existing Macs keep the current no-argument `./bootstrap.sh` and `./rebuild.sh` behavior, with implementation files under `mac/`.
- WSL gets Zsh, the editor, and development CLI from this checkout without receiving Mac GUI/system settings or editing tracked usernames; Bash remains usable.
- A no-root server can install Zsh locally and use the small editor/shell subset without Nix, sudo, or changes to its account login shell when build prerequisites are available; Bash remains usable.
- A server with working Nix may opt into the headless package profile; the default server route has no Nix prerequisite.
- Linux root commands require an explicit `wsl` or `server` selection; all profiles can also be invoked through their subfolder scripts.
- No path silently replaces an existing home config file or real `~/.dotfiles` directory.

## Facts to confirm during implementation

- The actual WSL architecture and default shell, plus whether Nix is already installed there.
- Which servers are personal and persistent enough to justify managed packages; their architectures, available editor, current shell, compiler/`make`, and terminal development libraries.
- Whether `unnamedplus` clipboard integration should differ between Mac, WSL, and SSH sessions.
