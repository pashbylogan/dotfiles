# Design History

This document records what changed in this repo, why it changed, the design principles behind the current shape, and the implementation issues that showed up during the transition.

## Starting Point

The repo started as a small `stow`-based dotfiles repo with:

- a simple `install` script that re-stowed top-level packages
- shell config in `zsh`
- editor config in `nvim`
- terminal config in `ghostty`
- window manager config in `i3`
- status bar config in `i3status`
- compositor config in `picom`
- SSH config in `ssh`
- tmux config in `tmux`
- utility scripts in `bin`
- desktop entry files in `desktops`

That setup worked for syncing config files, but it did not solve full machine setup. It assumed too much about the host machine and had no real system for:

- bootstrapping a fresh machine from almost nothing
- installing packages and dependencies
- upgrading software over time
- handling OS differences cleanly
- separating shared config from machine-local overrides
- keeping user-managed tools in predictable locations

## What Changed

### 1. Added a Real Bootstrap Path

New files:

- [bootstrap.sh](/home/pashbyl/projects/dotfiles/bootstrap.sh)
- [scripts/common.sh](/home/pashbyl/projects/dotfiles/scripts/common.sh)
- [scripts/apply](/home/pashbyl/projects/dotfiles/scripts/apply)
- [scripts/update](/home/pashbyl/projects/dotfiles/scripts/update)
- [scripts/check](/home/pashbyl/projects/dotfiles/scripts/check)

Why:

- The old repo assumed `git`, `stow`, and the rest of the environment already existed.
- The new goal was to assume a nearly blank host with only `curl` and the system package manager.
- The new bootstrap path installs prerequisites, clones or updates the repo, and hands off to the managed convergence flow.

Decision:

- Use a thin remote bootstrap script plus repo-managed logic.
- Keep the remote script small and easy to reason about.
- Avoid putting most logic in the raw `curl` entrypoint.

### 2. Added Ansible as the Convergence Layer

New structure:

- [ansible/site.yml](/home/pashbyl/projects/dotfiles/ansible/site.yml)
- [ansible/group_vars/all.yml](/home/pashbyl/projects/dotfiles/ansible/group_vars/all.yml)
- [ansible/vars/profiles/linux_desktop.yml](/home/pashbyl/projects/dotfiles/ansible/vars/profiles/linux_desktop.yml)
- [ansible/vars/profiles/macos_cli.yml](/home/pashbyl/projects/dotfiles/ansible/vars/profiles/macos_cli.yml)
- roles under `ansible/roles/`

Why:

- `stow` is good for placing files into `$HOME`.
- `stow` is not enough for packages, upgrades, user directories, runtime installation, or self-healing.
- The repo needed an idempotent engine that could install missing software and converge drift.

Decision:

- Keep `stow` for static home-directory config.
- Use Ansible for packages, upgrades, directory creation, user-managed runtimes, and orchestration.
- Add distro-specific Linux package maps so support is not accidentally Debian-only.

### 3. Kept the Existing Repo Layout Instead of Rewriting It

Why:

- The existing package layout was already understandable.
- Rewriting the whole repo to another dotfile manager would have increased churn without immediate payoff.
- The fastest safe path was to wrap the existing layout in better orchestration.

Decision:

- Keep top-level packages like `ssh`, `zsh`, `tmux`, `nvim`, `ghostty`, `i3`, `i3status`, `picom`, and `bin`.
- Replace the old role of `install` with a compatibility wrapper to the new apply flow.

### 4. Standardized Install Locations

Current policy:

- OS package manager for standard software and desktop packages
- `~/apps` for self-contained user-managed runtimes and SDK-like tools
- `~/.local/bin` for user executables and wrappers
- `~/.config`, `~/.ssh`, and similar paths for stowed config

Concrete decisions:

- `uv` lives in `~/apps/uv`
- `nvm` lives in `~/apps/nvm`
- Go state lives in `~/apps/go`
- package-manager-installed software stays in package-manager defaults
- Neovim is package-manager-managed rather than AppImage-managed

Why:

- The repo already had a `~/apps` convention.
- Not every package should be forced into `~/apps`; doing that raises maintenance cost.
- User-scoped runtimes benefit from being grouped under one predictable root.

### 5. Updated Shell Config to Match the New Model

Updated files:

- [zsh/.zshrc](/home/pashbyl/projects/dotfiles/zsh/.zshrc)
- [zsh/.zsh_profile](/home/pashbyl/projects/dotfiles/zsh/.zsh_profile)

What changed:

- removed hardcoded `/home/pashbyl/...` paths
- made `EDITOR` and `VISUAL` use `nvim`
- introduced `DOTFILES_APPS_ROOT`, `DOTFILES_LOCAL_BIN`, and `DOTFILES_LOCAL_SCRIPTS`
- moved Go state under `~/apps/go`
- guarded optional sources and paths so a fresh machine does not break on missing tools

Why:

- The old config was tightly bound to one existing machine layout.
- A bootstrap system has to tolerate partial state while it converges.
- The shell config needed to reflect package-manager installs and the new `~/apps` policy.

### 6. Updated Desktop Config for Better Portability

Updated file:

- [i3/.config/i3/config](/home/pashbyl/projects/dotfiles/i3/.config/i3/config)

What changed:

- terminal launch now prefers `ghostty` from `PATH`, with the old app-bundle path as fallback
- wallpaper setup only runs if the wallpaper exists
- `picom` startup checks whether `picom` is installed
- host-specific `xinput` tuning moved into [bin/.local/scripts/apply-xinput-settings](/home/pashbyl/projects/dotfiles/bin/.local/scripts/apply-xinput-settings)
- app-specific workspace assignment rules were reduced to the core terminal case

Why:

- The original desktop config assumed one machine, one device set, and one app set.
- That makes convergence brittle.
- Device-specific behavior belongs in a small host-aware helper, not the shared desktop config.

### 7. Cleaned Up SSH and Tmux

Updated files:

- [ssh/.ssh/config](/home/pashbyl/projects/dotfiles/ssh/.ssh/config)
- [ssh/.ssh/config.local.example](/home/pashbyl/projects/dotfiles/ssh/.ssh/config.local.example)
- [tmux/.tmux.conf](/home/pashbyl/projects/dotfiles/tmux/.tmux.conf)

What changed:

- SSH now has stronger defaults and a local include file for machine-private overrides
- tmux now uses the current shell as default, renumbers windows automatically, and supports clipboard copy on both macOS and Linux

Why:

- Shared config should stop at the point where values become machine-specific or private.
- tmux clipboard behavior should not assume Linux-only tooling.

### 8. Pruned Non-Essential Software and Personal Integrations

Removed from the managed core:

- the `desktops` package from the stow package list
- all desktop entry files under `desktops/.local/share/applications`
- shell integrations for `gcloud`, `tailscale`, `wg-quick`, `scrcpy`, `dbmate`, `claude`, `gemini`, and `autorandr`
- app-specific i3 placement rules for Slack, Firefox, Obsidian, IntelliJ, and Spotify
- `dbdump`, which depended on `dbmate`
- Linux package assumptions for `lxappearance`, `autorandr`, `blueman`, and `xbacklight`

Why:

- The repo had become a mix of core environment definition and personal utility clutter.
- A smaller base is easier to test in containers and easier to reason about.
- Optional app integrations can return later behind explicit feature flags or host/profile roles.

## Design Principles

### Start From an Almost-Blank Machine

Assume the machine only has:

- `curl`
- the system package manager

Everything else should be installed or converged by the repo.

### Prefer the Lowest-Maintenance Stable Source

- Use the OS package manager when it gives a current stable version with little maintenance overhead.
- Use `~/apps` for self-contained user-managed runtimes where that improves clarity.
- Avoid custom installation paths for ordinary packages if the package manager already solves the problem well.

### Keep Shared Config Generic

- Shared config should be valid on any machine in the profile.
- Private values and one-off host details should move to local override files or host-specific logic.
- Hardcoded usernames and absolute home paths should be removed from tracked config.

### Keep the Bootstrap Thin

- The `curl` entrypoint should do only enough to get the real system running.
- Most logic should live in the repo, under version control, where it can be reviewed and tested.

### Separate Static Files From Convergence Logic

- `stow` manages file placement.
- Ansible manages software, directories, runtime installation, and idempotent repair.

### Minimize Scope Before Testing

- A smaller supported surface is easier to validate.
- Non-essential integrations should not stay in the critical path just because they already exist.

## Important Decisions

### Why Not Move to Chezmoi, Yadm, or Nix Right Now

Those systems can be good fits, but they were not the shortest path from the current repo to a working bootstrap and convergence system.

Reasons:

- the repo already had a usable `stow` structure
- Ansible cleanly covers package install and machine convergence
- switching tool families immediately would add migration cost before solving the practical bootstrap problem

### Why Use Latest Stable Instead of Fully Pinned Versions

Decision:

- Track latest stable by default.
- Keep the option open to pin specific tools later if they prove too volatile.

Why:

- Full pinning adds maintenance burden quickly.
- The stated goal favored ease of maintenance and self-healing updates.

### Why macOS Is CLI-First

Decision:

- Linux desktop is the richer target for now.
- macOS support starts at CLI and terminal parity.

Why:

- The current repo is heavily Linux desktop shaped.
- Matching macOS UI defaults would expand scope before the core bootstrap/update system is proven.

## Issues We Faced

### 1. Sandbox Restrictions During Exploration

Problem:

- Basic repo inspection commands initially failed in the local sandbox.

Impact:

- We had to re-run inspection commands with elevated permissions before implementation could start.

### 2. The Repo Was Smaller Than It First Appeared

Problem:

- The tracked file set was minimal, while several directories existed with untracked or local-only content.

Impact:

- The new system had to be built around the actual tracked source of truth, not assumptions based on the working tree.

### 3. Existing Config Assumed One Specific Machine

Problem:

- Shell and desktop config contained hardcoded paths, device names, and app assumptions.

Impact:

- Those assumptions would have broken bootstrap on fresh or different machines.

Response:

- Path handling was normalized.
- device-specific behavior was isolated
- optional integrations were guarded or removed

### 4. `ansible-playbook` Was Not Installed Locally

Problem:

- The local machine did not have Ansible installed during implementation.

Impact:

- Shell syntax checks were possible
- full Ansible runtime validation was not yet possible in-place

Response:

- The new scripts were written to self-bootstrap missing prerequisites.
- Container-based testing became the next logical validation step.

### 5. Scope Creep From Personal Integrations

Problem:

- The repo contained a growing set of personal aliases, helper scripts, and app-specific behavior that did not belong in the core environment definition.

Impact:

- The first version of the managed system risked being too broad and harder to test.

Response:

- We deliberately pruned non-essentials before Docker testing.

### 9. Fixed Ansible Implementation Bugs Before First Real Run

Three bugs were caught during review before the playbook was ever run on a live machine:

**Homebrew install loops passed the entire registered result object to `brew install`.**

The check tasks registered results, and the install tasks looped over `results` but used `{{ item }}` (the whole result dict) instead of `{{ item.item }}` (the original package name). Both the formula and cask install tasks had the same mistake.

Fix: `brew install {{ item }}` → `brew install {{ item.item }}` in both tasks.

**Stow preview `changed_when` referenced the loop item instead of the command's own output.**

The preview task loops over stat results and runs `stow -n -v`. Its `changed_when` checked `item.stdout`, but `item` is a stat result (no stdout). Additionally, `stow -n -v` writes verbose output to stderr, not stdout.

Fix: `item.stdout` → `stderr` (the command's own stderr).

**Stow apply task referenced `item.stat.exists` on a command result.**

The apply task loops over preview results. It checked `item.stat.exists`, but `item` is a command result — the stat data would be at `item.item.stat.exists`. Replaced with `item.changed | default(false)` to use the preview's own changed flag, which already encapsulates "package exists and has pending changes."

**Linux package maps were missing identity entries for common packages.**

The `extract` filter maps abstract package names to distro-specific names. Packages whose names are the same across distros (git, curl, zsh, tmux, neovim, fzf, ripgrep, age, stow, unzip, ca-certificates) were not in the maps, so the filter would KeyError on every Linux run.

Fix: added identity entries to all four distro maps (apt, dnf, pacman, zypper).

### 10. Idempotency Audit and Fixes

A full review of every Ansible role for correct `changed` reporting and repeat-run safety turned up four additional issues:

**Shell role created a redundant `~/apps` directory with a hardcoded path.**

The shell role had its own `file: state=directory` task for `{{ ansible_env.HOME }}/apps`. This was redundant with the filesystem role (which already creates `{{ dotfiles_apps_root }}`) and used a hardcoded path instead of the variable. Removed the duplicate.

**Node.js LTS install ran on every `apply` and always reported `changed`.**

Added a version check that runs `nvm version default` first. The install task now only runs when no valid default exists (first run) or in `update` mode. On a converged machine, `apply` correctly reports no changes.

**Stow preview reported `changed` on every run because `stow -R -n -v` always shows UNLINK/LINK cycles for already-linked files.**

Switched the preview to `stow -S` (stow-only, not restow). With `-S`, stow only reports `LINK:` lines for files that actually need new symlinks. The `changed_when` now checks for `LINK:` in stderr specifically, ignoring the `WARNING: in simulation mode` line that always appears. The apply task still uses `-R` (restow) for completeness, including stale link cleanup. On `update` mode, apply always runs to ensure stale links are cleaned; on `apply` mode, it only runs when the preview detected new links needed.

**Dex compatibility shim ran on all dnf systems regardless of profile.**

The `dex-autostart` package is only installed for the `linux_desktop` profile, but the symlink task ran on all dnf systems, creating a broken symlink on non-desktop profiles. Added a `dotfiles_resolved_profile == "linux_desktop"` guard.

## Current State

The repo now aims to be:

- bootstrappable from a near-empty machine
- idempotent on repeat runs
- able to self-heal missing packages and config
- opinionated about install locations
- smaller and more testable than the original personal environment dump

The known Ansible implementation bugs have been caught and fixed before the first live run. The next major step is validation in Docker containers and then tightening whatever breaks under a genuinely fresh-machine workflow.

A full list of deliberately cut items that can be added back later is maintained in the README under "Not Managed (Optional Add-Backs)."
