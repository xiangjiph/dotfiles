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
| `shared/nvim/` | One Neovim configuration, plugin lockfile, theme, and keymaps used by all profiles. |
| `shared/claude/`, `shared/herdr/`, `shared/agents/` | Portable Claude settings/status line, Herdr keys/UI, and personal agent instructions used by all profiles. Configuring these tools does not install them. |
| `shared/config-links.tsv` | Source/target pairs for all shared config links, consumed by Home Manager and the no-Nix server. |
| `shared/home/` | Reusable Home Manager file links (`files.nix`), editor/Git packages (`editor.nix`), and workstation Zsh/Starship modules. |
| `shared/zsh/` | Small shared Zsh behavior used by Home Manager and the no-Nix server. |
| `shared/scripts/` | Safe repository/config link helpers, shared-manifest linker with conflict preflight, and Linux identity/architecture checks. |
| `tests/` | Isolated link/shell smoke tests, shared editor loading/fallback tests, and Home Manager profile contract checks. No system activation. |
| `README.md` | Supported user commands, prerequisites, and recovery. |

## Settings scope

| Setting | Mac | WSL | Server default | Server with Nix |
| --- | --- | --- | --- | --- |
| Neovim config, plugins, keymaps | Shared link | Shared link | Shared link; base fallback if prerequisites are missing | Shared link |
| Theme transparency | Yes | Yes (WSL kernel detection) | No on native Linux | No on native Linux |
| Claude settings/status line, agent instructions, Herdr config | Shared links | Shared links | Shared links | Shared links |
| Neovim and Git installation | Home Manager | Home Manager | Use server-installed tools | Home Manager |
| Zsh | Home Manager | Home Manager | Existing or user-local source build | Home Manager |
| Bash | Existing system shell | Remains available; interactive handoff to Zsh | Remains account shell; guarded interactive handoff | Remains account shell; guarded interactive handoff |
| Starship and Zsh plugins | Yes | Yes | Only if already installed; plain Zsh works | Plain Zsh by default |
| ripgrep/fd/fzf/jq | Home Manager | Home Manager | Use server-installed tools | Home Manager |
| WezTerm, font, Mac defaults, Homebrew apps | Mac only | No | No | No |

All Home Manager profiles import `shared/home/files.nix` and `shared/home/editor.nix`. The no-Nix server uses `shared/scripts/link-shared-config.sh`, which checks every manifest target before linking any of them. These paths install the same config links: Neovim, Herdr, Claude settings, and `shared/agents/AGENTS.md` as the personal instructions for Claude, Codex, and OpenCode. Home Manager retains its existing backup behavior; the no-Nix path refuses conflicting files or links.

Neovim loads the same plugins and keymaps on every OS. Neovim 0.10+, Git, and network access on first plugin installation are required for the plugin setup. Older Neovim, missing Git before installation, or a failed lazy.nvim clone leaves the base editor and keymaps usable. The plugin lockfile is `shared/nvim/lazy-lock.json`; the theme is transparent on Mac/WSL and opaque on native Linux. Text search needs ripgrep, Git features need Git, and `gd` needs an attached LSP server; this config does not install language servers or clipboard providers. The no-Nix server installs none of these tools automatically.

Claude's status line uses the shared script through `~/.dotfiles` instead of a fixed Mac username. It displays nothing when `jq` is absent. Herdr and agent configs are staged on Linux for separately installed applications; Homebrew still installs the existing Mac applications only.

## Reference synchronization

The common base with `../dotfiles` is `88a58cb`; `3a4392d` expanded this repository to WSL and server. The September 2026 reference working tree adds Neovim plugins/keymaps, Herdr configuration, Claude settings, and personal agent instructions. Those additions are portable and belong in `shared/`. The Mac system defaults, WezTerm settings, shell settings, and Darwin lock revisions already match the reference. Root entry points and separate Linux pins retain the expansion's behavior. There is no Mac-only editor tree or `nvim-local` extension.

Validation must not imply activation: syntax checks, temporary-home link tests, and mocked editor/profile tests can run without rebuilding. Full Nix evaluation and real Linux/application runtime checks should be reported separately when performed.

The Linux flake outputs read `USER` and `HOME` during `--impure` evaluation. Linux scripts verify those values against `id -un` and the account home, select x86_64 or aarch64, and pass `--impure`. WSL bootstrap may need sudo once for `/nix` when Nix is absent. The default server path never needs Nix or root, but building Zsh requires a C toolchain and terminal development libraries. The server source release and checksum live in `server/install-zsh.sh`.

## Maintenance workflow for future agents

When asked to change a setting for one OS:

1. Read this file and inspect the active profile, the shared modules, and corresponding settings in the other profiles. Check whether the edit belongs in `shared/` or only in the requested profile.
2. Implement and test the requested profile change. A shared-module edit that changes other profiles counts as synchronization and must wait for approval unless the user already requested those profiles. Use a local override when needed. Update this file and `README.md` if ownership, commands, prerequisites, or behavior changed.
3. Summarize the actual change and show the user which other profiles could take it. Present the specific synchronization edits and platform differences before making those cross-profile edits.
4. Wait for the user's approval before synchronizing into another OS profile. If the user explicitly requested a repository-wide or multi-profile change, that instruction is approval for those specified profiles.
5. After approved synchronization, test each affected profile and report what was applied. Preserve the Mac no-argument entry points and existing system/Homebrew settings unless the user requested changes to them.

Do not assume that a package or shell feature should be copied to a server just because it works on a workstation. The default server path is intentionally small and rootless. Existing home config files and unrelated user changes must be preserved.
