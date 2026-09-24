# Dotfiles architecture and maintenance contract

This is the authoritative map of the implemented repo. The earlier [migration plan](ubuntu-migration-plan.md) records the rationale and is not the source of current commands.

## Entry points and ownership

| Path | Role |
| --- | --- |
| `bootstrap.sh`, `rebuild.sh` | Root dispatchers. No argument selects Mac on Darwin; Linux requires `wsl` or `server`. They call matching subfolder scripts. |
| `flake.nix`, `flake.lock` | One root flake. `darwinConfigurations.mac` is the original Mac output; `homeConfigurations.wsl-*` and `server-*` are standalone Linux Home Manager outputs. Darwin inputs retain their original lock revisions; Linux Nixpkgs/Home Manager inputs are separate. |
| `mac/` | Mac-specific system and Home Manager modules, WezTerm config, and preserved nix-darwin bootstrap/rebuild implementations. |
| `wsl/` | Ubuntu/WSL standalone Home Manager profile and its bootstrap/rebuild scripts. Installs development CLI, Zsh, and Starship; manages Bash as a fallback. |
| `server/` | Default no-Nix server setup, pinned user-local Zsh source build, minimal Zsh startup, guarded interactive Bash handoff, and optional Home Manager headless profile. |
| `shared/nvim/` | One Neovim configuration used by all profiles. |
| `shared/home/` | Reusable Home Manager editor and workstation Zsh/Starship modules. |
| `shared/zsh/` | Small shared Zsh behavior used by Home Manager and the no-Nix server. |
| `shared/scripts/` | Safe repository/config link helpers and Linux identity/architecture checks. |
| `README.md` | Supported user commands, prerequisites, and recovery. |

## Settings scope

| Setting | Mac | WSL | Server default | Server with Nix |
| --- | --- | --- | --- | --- |
| Neovim config | Shared link | Shared link | Shared link | Shared link |
| Zsh | Home Manager | Home Manager | Existing or user-local source build | Home Manager |
| Bash | Existing system shell | Remains available; interactive handoff to Zsh | Remains account shell; guarded interactive handoff | Remains account shell; guarded interactive handoff |
| Starship and Zsh plugins | Yes | Yes | Only if already installed; plain Zsh works | Plain Zsh by default |
| ripgrep/fd/fzf/jq | Home Manager | Home Manager | Use server-installed tools | Home Manager |
| WezTerm, font, Mac defaults, Homebrew | Mac only | No | No | No |

The Linux flake outputs read `USER` and `HOME` during `--impure` evaluation. Linux scripts verify those values against `id -un` and the account home, select x86_64 or aarch64, and pass `--impure`. WSL bootstrap may need sudo once for `/nix` when Nix is absent. The default server path never needs Nix or root, but building Zsh requires a C toolchain and terminal development libraries. The server source release and checksum live in `server/install-zsh.sh`.

## Maintenance workflow for future agents

When asked to change a setting for one OS:

1. Read this file and inspect the active profile, the shared modules, and corresponding settings in the other profiles. Check whether the edit belongs in `shared/` or only in the requested profile.
2. Implement and test the requested profile change. A shared-module edit that changes other profiles counts as synchronization and must wait for approval unless the user already requested those profiles. Use a local override when needed. Update this file and `README.md` if ownership, commands, prerequisites, or behavior changed.
3. Summarize the actual change and show the user which other profiles could take it. Present the specific synchronization edits and platform differences before making those cross-profile edits.
4. Wait for the user's approval before synchronizing into another OS profile. If the user explicitly requested a repository-wide or multi-profile change, that instruction is approval for those specified profiles.
5. After approved synchronization, test each affected profile and report what was applied. Preserve the Mac no-argument entry points and existing system/Homebrew settings unless the user requested changes to them.

Do not assume that a package or shell feature should be copied to a server just because it works on a workstation. The default server path is intentionally small and rootless. Existing home config files and unrelated user changes must be preserved.
