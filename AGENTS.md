# Repository maintenance

Read [agent/ARCHITECTURE.md](agent/ARCHITECTURE.md) before changing a setting, package, shell behavior, or bootstrap/rebuild flow in this repository.

At the start of maintenance work, inspect `git status` and the diff so changes already made by the user are visible. When a setting changes in one profile, inspect the corresponding Mac, WSL, server, and shared definitions. Determine whether the change is genuinely shared or intentionally platform-specific. Update `agent/ARCHITECTURE.md` so its file map and behavior matrix match the proposed code.

When synchronizing from the original Mac repository, use the common git history to distinguish newer settings from the OS expansion. A setting is not Mac-specific merely because it came from that repository. Keep portable settings in `shared/`, with consistent behavior across the requested profiles; retain platform differences only for actual OS or tool limitations. `shared/config-links.tsv` is the common config-link manifest for Home Manager and the no-Nix server. Keep the migration plan's follow-up notes and README consistent with the architecture.

For a request limited to one OS, do not edit a shared module if that would change another profile before the user approves that synchronization. Use a profile-local setting or present the shared edit as a proposed change.

Before synchronizing a change into another OS profile, show the user:

1. What changed in the original profile.
2. Which other profiles could use the change, and any platform limitations.
3. The exact proposed edits and validation results.

Wait for the user's approval before applying the cross-profile synchronization. Do not infer approval from the original single-profile request. Changes explicitly requested for multiple profiles, or a repository-wide change already authorized by the user, may proceed without another approval request. Preserve the existing Mac `./bootstrap.sh` and `./rebuild.sh` entry points and test the affected profiles after edits.
