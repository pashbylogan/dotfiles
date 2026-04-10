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

- [bootstrap.sh](../bootstrap.sh)
- [scripts/common.sh](../scripts/common.sh)
- [scripts/apply](../scripts/apply)
- [scripts/update](../scripts/update)
- [scripts/check](../scripts/check)

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

- [ansible/site.yml](../ansible/site.yml)
- [ansible/group_vars/all.yml](../ansible/group_vars/all.yml)
- [ansible/vars/profiles/linux_desktop.yml](../ansible/vars/profiles/linux_desktop.yml)
- [ansible/vars/profiles/macos_cli.yml](../ansible/vars/profiles/macos_cli.yml)
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

- [zsh/.zshrc](../zsh/.zshrc)
- [zsh/.zsh_profile](../zsh/.zsh_profile)

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

- [i3/.config/i3/config](../i3/.config/i3/config)

What changed:

- terminal launch now prefers `ghostty` from `PATH`, with the old app-bundle path as fallback
- wallpaper setup only runs if the wallpaper exists
- `picom` startup checks whether `picom` is installed
- host-specific `xinput` tuning moved into [bin/.local/scripts/apply-xinput-settings](../bin/.local/scripts/apply-xinput-settings)
- app-specific workspace assignment rules were reduced to the core terminal case

Why:

- The original desktop config assumed one machine, one device set, and one app set.
- That makes convergence brittle.
- Device-specific behavior belongs in a small host-aware helper, not the shared desktop config.

### 7. Cleaned Up SSH and Tmux

Updated files:

- [ssh/.ssh/config](../ssh/.ssh/config)
- [ssh/.ssh/config.local.example](../ssh/.ssh/config.local.example)
- [tmux/.tmux.conf](../tmux/.tmux.conf)

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

The system has been validated in Docker containers across Ubuntu, Fedora, Arch, and openSUSE. Both `scripts/apply` (fresh install) and `scripts/update` (upgrade path) pass on all four distros.

### Full Managed Software List

Everything below is installed and kept up to date by the playbook.

**OS packages (all profiles):**

| Abstract name | What it is |
|---------------|-----------|
| `git` | version control |
| `curl` | HTTP client |
| `ca-certificates` | root certificate bundle |
| `stow` | symlink farm manager |
| `zsh` | shell |
| `tmux` | terminal multiplexer |
| `neovim` | editor |
| `fzf` | fuzzy finder |
| `ripgrep` | search |
| `fd` | file finder |
| `age` | encryption |
| `unzip` | archive utility |
| `build_tools` | compiler toolchain (gcc, make, etc.) |
| `python` | Python 3 + pip |
| `xterm_terminal` | fallback terminal for first boot |

**OS packages (linux_desktop profile only):**

| Abstract name | What it is |
|---------------|-----------|
| `i3` | tiling window manager |
| `i3status` | status bar |
| `i3lock` | screen locker |
| `xss-lock` | auto-lock on idle |
| `feh` | wallpaper / image viewer |
| `pavucontrol` | PulseAudio volume control |
| `thunar` | file manager |
| `rofi` | application launcher |
| `picom` | compositor |
| `dex` | autostart `.desktop` entries |
| `nm_applet` | NetworkManager tray applet |
| `jetbrains_mono_fonts` | terminal/editor font |

**OS packages (macOS via Homebrew):**

All core CLI packages above via `brew install`, plus `ansible`. Ghostty via `brew install --cask ghostty`.

**User-managed runtimes (~/apps):**

| Tool | Location | Install method | Update method |
|------|----------|---------------|---------------|
| uv | `~/apps/uv` | astral.sh installer | re-run installer |
| fnm | `~/.local/share/fnm` | fnm.vercel.app installer | re-run installer |
| Node.js LTS | via fnm | `fnm install --lts` | re-run install |
| npm (latest) | via fnm/node | `npm install -g npm@latest` | re-run install |

**Shell tooling:**

| Tool | Location | Install method | Update method |
|------|----------|---------------|---------------|
| oh-my-zsh | `~/.oh-my-zsh` | git clone | git pull |

**Stow packages (symlinked into $HOME):**

| Package | What it manages |
|---------|----------------|
| `ssh` | `~/.ssh/config`, `~/.ssh/config.local.example` |
| `nvim` | `~/.config/nvim/` |
| `tmux` | `~/.tmux.conf` |
| `zsh` | `~/.zshrc`, `~/.zsh_profile`, `~/.zsh_extras.example` |
| `bin` | `~/.local/scripts/*` (user utility scripts) |
| `ghostty` | `~/.config/ghostty/` |
| `i3` | `~/.config/i3/config` (linux_desktop only) |
| `i3status` | `~/.config/i3status/config` (linux_desktop only) |
| `picom` | `~/.config/picom/picom.conf` (linux_desktop only) |

**Directories created by the filesystem role:**

`~/apps`, `~/apps/bin`, `~/apps/go` (+ bin, cache, config, pkg subdirs), `~/apps/src`, `~/apps/tmp`, `~/.local/bin`, `~/.local/scripts`, `~/.local/share`, `~/.local/share/backgrounds`

### Deferred Software (Not Managed)

The following were deliberately cut to keep the base small. See the README for the full list. They can be added back behind profile flags or host-specific roles.

- Desktop `.desktop` launchers (Discord, IntelliJ, Obsidian, Postman, Thunderbird)
- i3 workspace rules (Firefox, Slack, Obsidian, JetBrains IDEA, Spotify)
- Shell wrappers (claude, gemini, gssh, vpns/exitnode, android, dbmate/dbdump, autorandr, cdwt, gcloud, cloud-sql-proxy)
- Linux packages (blueman, xbacklight, lxappearance, autorandr)

### Future Work

Potential additions that are well-maintained and widely adopted. None are blocking — the current setup is fully functional without them.

**Shell plugins** (add to oh-my-zsh `plugins` list or `$ZSH_CUSTOM/plugins`):

| Plugin | Stars | What it does |
|--------|-------|-------------|
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | ~35k | Fish-like inline history suggestions as you type |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | ~22k | Colors valid/invalid commands in real time |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | ~35k | Smarter `cd` — learns your frequent directories, replaces `z`/`autojump` |

**Terminal tools** (install via package manager, alias in shell config):

| Tool | Stars | What it does |
|------|-------|-------------|
| [bat](https://github.com/sharkdp/bat) | ~58k | `cat` with syntax highlighting and line numbers |
| [eza](https://github.com/eza-community/eza) | ~21k | Modern `ls` with git status, icons, tree view |
| [delta](https://github.com/dandavison/delta) | ~30k | Syntax-highlighted git diffs, set as `core.pager` in gitconfig |
| [lazygit](https://github.com/jesseduffield/lazygit) | ~76k | Full TUI for git — staging, rebasing, conflict resolution |
| [tldr](https://github.com/tldr-pages/tldr) | ~62k | Simplified man pages with practical examples |

**Tmux plugins** (via [tpm](https://github.com/tmux-plugins/tpm), ~14k stars):

| Plugin | Stars | What it does |
|--------|-------|-------------|
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | ~13k | Persist tmux sessions across reboots |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | ~3k | Standardized system clipboard integration |

**Neovim** (already has lazy.nvim via stow):

| Plugin | Stars | What it does |
|--------|-------|-------------|
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | ~19k | Fuzzy finder for files, grep, buffers — pairs with fzf/rg/fd |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | ~14k | AST-based syntax highlighting and code navigation |

**i3 desktop** (Linux only):

| Tool | Stars | What it does |
|------|-------|-------------|
| [dunst](https://github.com/dunst-project/dunst) | ~5.4k | Notification daemon — needed for `notify-send` to display anything |
| [flameshot](https://github.com/flameshot-org/flameshot) | ~30k | Screenshot tool with annotation GUI, replaces `import + xclip` |
| [polybar](https://github.com/polybar/polybar) | ~15k | Highly configurable status bar replacement for i3status (high effort) |

**Security/privacy**:

| Tool | Stars | What it does |
|------|-------|-------------|
| [gopass](https://github.com/gopasspw/gopass) | ~6.8k | CLI password manager, compatible with `pass`, works with GPG or age |
