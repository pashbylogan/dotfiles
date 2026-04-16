# Design History

This document records what changed in this repo, why it changed, the design principles behind the current shape, and the implementation issues that showed up during the transition.

> **Scope note (April 15, 2026):** This document is primarily historical. The repository now supports **Fedora Linux only** (`dnf`/`dnf5`). References below to multi-distro support or macOS describe earlier iterations.

## Current Support Snapshot

- Supported OS: **Fedora Linux only**
- Supported package manager: **dnf / dnf5**
- Supported profile: **linux_desktop**
- Removed since earlier revisions: `macos_cli` profile, Homebrew package path, and non-Fedora Linux package maps (`apt`, `pacman`, `zypper`)

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
- `fnm` lives in `~/.local/share/fnm`
- `starship` lives in `~/apps/bin` (single-binary tools installed by curl go here)
- Go state lives in `~/apps/go`
- package-manager-installed software stays in package-manager defaults
- Neovim is package-manager-managed rather than AppImage-managed

Rule: if a tool is installed via a curl installer (not a package manager), its binary goes under `~/apps` — either `~/apps/<tool>` for tools with their own directory structure (uv, fnm) or `~/apps/bin` for single-binary tools (starship). `~/.local/bin` is reserved for user scripts and wrappers managed by stow, not for curl-installed binaries.

Explicitly **not** managed globally:

- **Java** — managed per-project by IntelliJ (downloads JDKs to `~/.jdks/`) or `mise` if needed from the command line. No global JDK install.
- **Gradle** — always use the Gradle Wrapper (`./gradlew`). Each project's `gradle-wrapper.properties` pins its version. A global Gradle install is unnecessary.

Both `~/apps/java` and `~/apps/gradle` can be removed from existing machines. If a CLI JDK is ever needed outside IntelliJ, use `mise` (Rust-based universal version manager with per-project `.mise.toml` support) rather than a global install.

**Desktop apps** (Discord, Obsidian, Postman, Thunderbird, IntelliJ, etc.) are not managed by this repo. Install them manually using:

- **Flatpak** (preferred) — `flatpak install flathub com.discordapp.Discord` etc. Auto-creates `.desktop` entries, handles updates, works across distros.
- **JetBrains Toolbox** — for IntelliJ and other JetBrains IDEs. Self-updates, creates `.desktop` files.
- **Package manager** — for apps in default repos (e.g., Thunderbird).

Avoid manual extract-to-`~/apps` + hand-written `.desktop` files for desktop apps. That pattern doesn't handle updates and breaks when paths change.

`~/apps/bin` is for single-binary CLI tools. `~/apps/<tool>` is for CLI tools with their own directory structure. Desktop app bundles should not live in `~/apps`.

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

### 11. Replaced oh-my-zsh with Plain Zsh + Starship

oh-my-zsh loaded 150+ files for 2 plugins (`git`, `fzf`) that were both redundant — we already had custom git aliases and fzf ships its own shell integration. Replaced with ~100 lines of direct zsh config preserving everything that mattered: completion (case-insensitive, substring matching, menu select), history (50k shared, dedup, prefix search with arrow keys), key bindings (Home/End/Ctrl-arrows, edit-command-line), and fzf integration with fallback for older versions.

Prompt replaced with Starship (Rust binary, ~2ms init). Installed to `~/apps/bin` via curl installer.

### 12. Replaced nvm with fnm

nvm added ~300ms to every shell open (even with lazy-loading, the first `node`/`npm` call paid the full penalty). fnm is a Rust binary with <1ms shell init, reads `.nvmrc` natively, and is a near-drop-in replacement. Installed to `~/.local/share/fnm` via curl installer.

### 13. Replaced pnpm with corepack

pnpm was installed globally to `~/.local/share/pnpm` with a PATH entry. Replaced with corepack (ships with Node.js) — `pnpm`/`yarn` are available on-demand per-project when `package.json` specifies a `packageManager` field. No global install, no PATH entry, no version to maintain.

### 14. Migrated from i3+X11 to Sway+Wayland

X11 is in maintenance mode — no new development upstream. All major distros now default to Wayland. The migration was motivated by three goals:

1. Should be on actively maintained software (X11 is maintenance-only)
2. Should align with Linux defaults (Fedora, Ubuntu, Arch, openSUSE all ship Wayland)
3. Should simplify the desktop environment setup, config, and maintenance

Sway was chosen over Hyprland because it is in default repos on all four distros (Hyprland is not in Ubuntu/Debian), uses i3-compatible config syntax (near-trivial migration), and uses the standard wlroots tool ecosystem (no parallel lock/idle/wallpaper tools to track). Hyprland optimizes for visual polish at the cost of stability, portability, and simplicity.

The migration eliminated picom (Sway is the compositor), the `apply-xinput-settings` script (replaced by sway `input {}` blocks), feh, maim, xclip, i3lock, xss-lock, xterm, xset, and setxkbmap. The empty `desktop_linux` Ansible role was also deleted at the time (later brought back with real content for dark-mode / Tracker dconf tasks — see section 21).

Added: sway, swaylock, swayidle, swaybg, grim, slurp, wl-clipboard, brightnessctl (replaces orphaned `light`), mako (notification daemon — we had none before), xdg-desktop-portal-wlr (screen sharing), foot (lightweight Wayland terminal fallback), and kanshi (replaces autorandr for per-dock display profiles; see section 20).

**Blur**: Sway does not support compositor-level blur (dual_kawase). Ghostty's own `background-opacity = 0.8` still works natively. A new `ext-background-effect-v1` Wayland protocol was merged into wayland-protocols in May 2025, which will let any client request blur from any supporting compositor. No compositor has shipped a stable implementation yet. When Sway adds support, blur will return without needing SwayFX or Hyprland. This is the planned path.

### 15. Added delta and btop

delta: syntax-highlighted git diffs with line numbers, configured via `git config` in the Ansible shell role. Replaces raw `diff` output.

btop: modern process viewer replacing `top`/`htop`. Both are in default repos on all four distros.

### 16. Security Hardening

Full audit resulted in: SSH config consolidated with `ForwardAgent no`, `ForwardX11 no`, `HashKnownHosts yes`; host-specific entries moved to gitignored `config.local`; post-stow `chmod 700 ~/.ssh` and `chmod 600 ~/.ssh/config`; `host_key_checking = False` removed from `ansible.cfg`; profile and package manager names validated before `include_vars`; directory permissions tightened to `0700`; absolute path for fnm eval; defensive `.gitignore` patterns for keys, `.env`, vault files; quoted variables in shell scripts and i3 config.

### 17. Added WireGuard and Tailscale

WireGuard tools added to common Linux packages (in default repos on all distros). Tailscale added via a dedicated Ansible role that adds the Tailscale repo on apt/dnf, then installs the package. Arch and openSUSE have Tailscale in their default repos.

### 18. Set zsh as the Login Shell

Installing zsh isn't enough — new terminals still open bash by default on every distro, so none of the zsh config would run. Added three idempotent Ansible tasks to the shell role: locate zsh via `command -v`, ensure the path is in `/etc/shells`, and set it as the user's login shell via `ansible.builtin.user`. Works across all four distros and macOS since the zsh path is discovered at runtime.

### 19. Cleanup Script

Added `scripts/cleanup` — an interactive script that, after confirming the new environment works, removes:

- Default desktop environments (GNOME shell, KDE, etc.) that are no longer used
- Display managers (GDM, SDDM, LightDM) replaced by TTY login + `exec sway`
- X11 tools replaced by Wayland equivalents (i3, picom, feh, maim, xclip, xterm, xss-lock, htop, light)
- Orphaned config/cache directories in `$HOME` for software that's no longer installed (including `~/.screenlayout/` from arandr/autorandr, replaced by kanshi)
- Package manager caches

Interactive by design — shows exactly what would be removed and asks before each phase. Never runs automatically. Complements the install-only policy from section 17 (we never auto-remove packages; this is an explicit user-invoked cleanup).

### 20. Replaced autorandr with kanshi

autorandr drives `xrandr` and doesn't work under Wayland. The Wayland equivalent is kanshi — a small daemon that listens for output hotplug events and applies profiles based on which monitors are connected. Available by the same package name (`kanshi`) on all four distros, actively maintained, and the standard recommendation in the Sway wiki.

Kanshi config is ~100% machine-specific (monitor make/model/serial strings, dock layouts), so the repo ships only a template at `~/.config/kanshi/config.example`. The real `~/.config/kanshi/config` is gitignored and created by the user via `cp config.example config`, following the same pattern as `~/.zsh_extras` and `~/.config/sway/config.local`.

Started by `exec kanshi` in sway config, so no separate service to manage. No alias needed — it auto-switches when monitors are plugged or unplugged.

### 21. Replaced Thunar with Nautilus (and added system-wide dark mode)

Thunar was originally chosen for its light dependency footprint, but it looks dated in 2026. Nautilus (GNOME Files) has had a GTK4 / libadwaita rewrite and is now the best-looking portable Linux file manager. Available by the same package name (`nautilus`) on all four distros, Wayland-native, and actively maintained.

Considered and rejected: **Dolphin** (pulls 300-500 MB of KDE frameworks), **Nemo** (no real visual upgrade over Thunar and still GTK3/XWayland), **PCManFM-Qt** (looks worse than Thunar), and **Cosmic Files** (not yet in distro repos — likely the right pick in 1-2 years).

Nautilus's GNOME footprint is kept minimal:

- **libadwaita, gsettings-desktop-schemas, gvfs** come along as deps. These are theming/schema/VFS libs, not desktop-environment components.
- **Tracker3** (the indexer daemon) is a dep but we neutralise it via dconf: `/org/freedesktop/Tracker3/Miner/Files/index-recursive-directories` and `index-single-directories` are both set to empty arrays, so the miner runs but has nothing to scan. Cleaner than masking the systemd unit because Tracker can also be D-Bus activated.
- **No GNOME shell, gnome-session, gnome-control-center, or other DE components**. `scripts/cleanup` explicitly keeps Nautilus out of the GNOME-removal list.

**Dark mode** is set system-wide via a new `desktop_linux` Ansible role using `community.general.dconf`:

- `/org/gnome/desktop/interface/color-scheme` → `'prefer-dark'` — the canonical switch for libadwaita / modern GTK4. Nautilus picks this up directly from dconf even without `xdg-desktop-portal-gtk` providing the Settings portal.
- New `gtk` stow package writes `gtk-application-prefer-dark-theme=1` to `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` as a fallback for legacy GTK3 apps and plain (non-libadwaita) GTK4 apps.

Libadwaita and the `settings.ini` mechanism target different codepaths and don't conflict. `gtk-theme` is deliberately NOT forced to `Adwaita-dark` so users who install a different GTK theme still see it.

The role runs as the logged-in user (no `become`) and requires `scripts/apply` to be executed from inside a graphical session so `DBUS_SESSION_BUS_ADDRESS` is set. This is consistent with how the rest of the playbook runs.

### 22. Omarchy-inspired audio, Bluetooth, and power management

Borrowed selectively from [Omarchy](https://github.com/basecamp/omarchy) (DHH's opinionated Arch distribution, known for excellent laptop battery life). Took the portable pieces; skipped anything Hyprland-specific, Arch-specific, or that conflicted with our multi-distro promise.

**Audio — PipeWire + WirePlumber.** Previously implicit (pavucontrol assumed it was there but we never installed it). Now explicit: `pipewire`, `wireplumber`, `pipewire-pulse` (PulseAudio compat), `pipewire-alsa`, `pipewire-jack`. A new `wireplumber` stow package ships `api.alsa.soft-mixer = true` for consistent bluetooth audio volume. User services (`pipewire.socket`, `pipewire-pulse.socket`, `wireplumber.service`) are explicitly enabled to work around Arch's manual-enable quirk.

**Bluetooth — BlueZ + Blueman.** Omarchy uses `bluetui` (Rust TUI) but it's only in Arch and openSUSE repos. Blueman is universally available, provides a GTK tray applet people expect, and matches what was originally in the pre-ansible README. `bluetooth.service` is enabled at boot.

**Power management — `power-profiles-daemon`, not TLP.** Omarchy's key insight: on modern hardware (2022+), the kernel's own power management is good enough that TLP's aggressive tuning is counterproductive. `power-profiles-daemon` with udev-driven profile switching is the right abstraction. Installed pieces:

- `/etc/udev/rules.d/99-power-profile.rules` — switches `balanced` on battery, `performance` on AC, via `powerprofilesctl`.
- `/etc/udev/rules.d/99-wifi-powersave.rules` + `/usr/local/bin/wifi-powersave` — toggles `iw dev <iface> set power_save on/off` to match AC state.
- `/usr/lib/systemd/system-sleep/unmount-fuse` — unmounts `gvfsd-fuse` mounts before suspend to prevent Nautilus from hanging suspend.
- `/etc/systemd/system.conf.d/10-faster-shutdown.conf` — `DefaultTimeoutStopSec=5s` (kills the 90-second shutdown hang).
- `/etc/systemd/system/user@.service.d/10-faster-shutdown.conf` — same for user services.
- `/etc/systemd/system/plocate-updatedb.service.d/ac-only.conf` — `ConditionACPower=true` so disk indexing doesn't run on battery.
- `~/.config/systemd/user/battery-monitor.{service,timer}` + `~/.local/scripts/battery-monitor` — systemd user timer fires every 30s, sends a critical `notify-send` at ≤10% battery, flag file prevents repeat notifications until charging resumes.

**Skipped:** `thermald` (Intel-only; user is moving to AMD), `intel-lpmd` (Arch-only). These can be added later if needed.

### 23. iwd as NetworkManager's WiFi backend (opt-in)

Omarchy uses pure `iwd` + `impala` (no NetworkManager). Full swap is too invasive for a portable dotfiles repo — NetworkManager is the default on all four distros and handles VPN plugins, enterprise WiFi, cellular, and the tray applet. But the Arch wiki-recommended middle ground — NetworkManager with `wifi.backend=iwd` — gives us iwd's battery and connect-speed benefits while keeping NM's ergonomics.

Gated behind `dotfiles_iwd_backend_enabled: false` in `group_vars/all.yml` because the swap disables `wpa_supplicant` and restarts NetworkManager, which briefly drops active WiFi connections. Opt-in by flipping the default to `true`.

When enabled, the role writes `/etc/NetworkManager/conf.d/wifi-backend.conf`, disables `wpa_supplicant.service`, enables `iwd.service`, and restarts NetworkManager in the correct order.

### 24. Modernised git defaults

Four upstream git-recommended defaults added to the existing delta pager config:

- `diff.algorithm=histogram` — smarter hunking than the default `myers`.
- `rerere.enabled=true` — remembers conflict resolutions so you don't replay them on every rebase.
- `push.autoSetupRemote=true` — first push on a new branch works without `--set-upstream`.
- `branch.sort=-committerdate` — recent branches at the top of `git branch` output.

These are baked in via the existing `community.general.git_config` task in the shell role, so they pin idempotently across runs.

### 25. Downstream adjustments for the new stack

Three follow-on tweaks to actually exercise the new backends rather than leave them installed but unused:

**Sway volume bindings → `wpctl`.** Old bindings used `pactl set-sink-volume` which still works via pipewire-pulse compat, but the PipeWire-native command is `wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+`. The `-l 1.0` flag caps raise at 100% so a stuck repeat key can't overdrive speakers (wpctl allows boost-above-100% by default, pactl didn't). Same for mute toggles (`wpctl set-mute … toggle`).

**Fontconfig fallbacks for CSS `system-ui`.** New `fontconfig` stow package ships a `fonts.conf` that maps `system-ui`, `-apple-system`, and `BlinkMacSystemFont` → Liberation Sans + Noto Color Emoji. Without this, websites that specify the macOS system font stack (common on modern sites copying Apple's design system) fall through to a serif, making them look broken on Linux. Adapted from Omarchy.

**`xdg-desktop-portal-gtk` for Firefox / Electron dark mode.** `xdg-desktop-portal-wlr` handles screen sharing but doesn't implement the `org.freedesktop.portal.Settings` interface. Without a Settings-capable portal, Firefox can't find our `color-scheme` dconf key and its chrome stays light. `xdg-desktop-portal-gtk` fills that gap — it reads GSettings and exposes `color-scheme` over D-Bus. Works fine on non-GNOME systems. New `xdg-portals` stow package writes `~/.config/xdg-desktop-portal/sway-portals.conf` to route Settings to `gtk` while keeping Screenshot/ScreenCast on `wlr`.

**Cleanup script extensions.** `scripts/cleanup` now also offers to remove packages that conflict with the new stack if they were previously installed: `tlp`, `tlp-rdw`, `auto-cpufreq`, `tuned`, `tuned-ppd`, `powertop` (fight power-profiles-daemon for the same kernel knobs), `pulseaudio`/`pulseaudio-utils`/`pulseaudio-bluetooth` (replaced by pipewire + pipewire-pulse compat), and `mlocate`/`locate` (replaced by plocate).

### 26. Idle inhibit for fullscreen video

On stock Sway, fullscreen YouTube / Netflix / Jellyfin etc. would trigger the screen lock after 5 minutes because two different bugs in the idle-inhibit chain defeated the normal "video is playing, stay awake" path:

1. **Portal misdirect.** Firefox and Chromium prefer the D-Bus `org.freedesktop.ScreenSaver.Inhibit` route when a portal backend advertises it. `xdg-desktop-portal-gtk` does advertise it, but it forwards to `org.gnome.SessionManager` — which doesn't exist on a Sway session. Browsers consider the request "handled," never fall back to the native Wayland protocol, and the inhibit request goes into a void. Fixed by adding `org.freedesktop.impl.portal.Inhibit=none` to our `sway-portals.conf` — this tells xdg-desktop-portal to refuse to handle Inhibit, which makes browsers fall back to `idle-inhibit-unstable-v1` (which Sway implements correctly).

2. **No compositor-level safety net.** Apps that don't speak the Wayland protocol at all (many Electron apps, X11 apps via XWayland, some games) can't inhibit idle no matter what. Fixed by adding two `for_window` rules:

   ```
   for_window [app_id=".*"] inhibit_idle fullscreen
   for_window [class=".*"] inhibit_idle fullscreen
   ```

   These tell Sway: for any matching window, inhibit idle *only while it's fullscreen*. The first matches native Wayland clients (`app_id`), the second matches XWayland clients (`class`). Sway creates the inhibitor itself — no app cooperation required.

Defence in depth: the portal fix handles windowed/PiP video playback in browsers; the catch-all fullscreen rule handles everything else. Together, `swayidle` never fires its lock timeout while a fullscreen window or actively-playing browser tab is on screen.

### 27. Replaced swaybar + i3status with Waybar

i3status had no modules for bluetooth state, the active power profile, or idle-inhibit status — three things that became relevant after recent additions (`power-profiles-daemon`, `bluez`/`blueman`, the fullscreen idle-inhibit fix). Waybar ships all three as native modules, plus `sway/workspaces` integration. Available as `waybar` in all four distros.

Migration is a clean replacement: swaybar (the compositor's fallback bar) goes away with the `bar { }` block, i3status is uninstalled, and waybar runs as a standalone bar via `exec waybar`. The `killall -SIGUSR1 i3status` kick after volume changes is also gone — waybar's `[pulseaudio]` module listens to PipeWire events directly.

The config deliberately leans on upstream defaults. Only the module list is opinionated — heights, margins, module formats, and the stylesheet are all left at waybar's defaults so cosmetic drift is upstream's problem. No `style.css` is stowed; waybar falls back to `/etc/xdg/waybar/style.css` from the package.

### 28. Desktop polish and safety pass (Fedora Everything)

Target install is **Fedora Everything 43** (Workstation's defaults are not available). This pass fills every gap that Workstation would ordinarily cover.

**Desktop integration.** `mate-polkit` (autostarted from sway, exec `/usr/libexec/polkit-mate-authentication-agent-1`) replaces `polkit-gnome`, removed in Fedora 41+. `gnome-keyring` provides the Secret Service backend via `authselect enable-feature with-pam-gnome-keyring` — without GDM to wire it, Sway-only sessions need the authselect opt-in. Nautilus depends on `gvfs-mtp`, `gvfs-smb`, `gvfs-nfs`, `ffmpegthumbnailer`, `webp-pixbuf-loader` for phone/SMB/NFS browsing and thumbnails.

**Fonts and icons.** `google-noto-color-emoji-fonts`, `google-noto-sans-cjk-vf-fonts`, `cascadia-mono-nf-fonts` (Microsoft Cascadia Mono with Nerd Font glyphs — main F43 repo, kicks in via fontconfig fallback when waybar/tmux requests Nerd glyphs), `adwaita-icon-theme` + dconf `icon-theme = 'Adwaita'`.

**Visual feedback.** `swayosd-server` autostarts from sway; `swayosd-client` replaces raw wpctl/brightnessctl bindings with combined hardware-change + on-screen-indicator calls. `playerctl` covers `XF86AudioPlay/Pause/Next/Prev`. swayosd ships via COPR `erikreider/swayosd` — `wob` is the main-repo alternative but requires per-binding shell glue that costs more than the COPR.

**Mako DND.** `[urgency=critical] default-timeout=0` pins critical alerts; `[mode=do-not-disturb] invisible=true` silences everything else. Critical still pops in DND. Toggle via `makoctl mode -t do-not-disturb`.

**Safety drop-ins.**

- `/etc/sysctl.d/90-dotfiles.conf` — `fs.inotify.max_user_watches=524288` (default 8192 is easy to hit) and `net.ipv4.tcp_mtu_probing=1` (fixes SSH stalls over MTU-black-hole paths).
- `/etc/systemd/logind.conf.d/10-handle-power-key.conf` — `HandlePowerKey=ignore`.
- `authselect enable-feature with-faillock` + `/etc/security/faillock.conf` set `deny=10 unlock_time=120`. `/etc/sudoers.d/10-passwd-tries` sets `passwd_tries=10`. Default 3/600 is user-hostile.

**Power hardening.** `/usr/local/bin/dotfiles-ppd-apply` (single helper, no-ops on systems without a battery, performance→balanced fallback) is invoked by the udev rules via `systemd-run --no-block --collect --after=power-profiles-daemon.service` to defer execution until PPD is running. `dotfiles-ppd-boot-sync.service` (system oneshot, After/Requires PPD) calls `dotfiles-ppd-apply auto` at boot to sync profile to current AC state — udev rules only fire on *changes*.

**Compressed swap + resolved.** `zram-generator-defaults` ships the vendor config (50% RAM, zstd, 8 GiB cap). `systemd-resolved.service` enabled + `/etc/resolv.conf` force-symlinked to the stub; NetworkManager auto-integrates.

**Default apps.** `mpv` + `imv` defaulted for 9 video + 9 image mimetypes via `~/.config/mimeapps.list` written by `community.general.ini_file`. mpv uses main-repo `ffmpeg-free`; enable RPM Fusion + `dnf swap ffmpeg-free ffmpeg` if HEVC/proprietary codecs come up.

**Third-party repos.** One COPR, pinned in `group_vars/all.yml` under `dotfiles_copr_repos` and enabled idempotently from the `packages` role via `creates:`:

- `erikreider/swayosd` — `swayosd`. Main-repo `wob` requires per-binding shell glue.

For Nerd Font glyphs we use `cascadia-mono-nf-fonts` from Fedora main — same glyph coverage as the popular `jetbrains-mono-nerd-fonts` COPR packages but no third-party repo needed.

## Current State

The system has been validated in Docker containers across Ubuntu, Fedora, Arch, and openSUSE. Both `scripts/apply` (fresh install) and `scripts/update` (upgrade path) pass on all four distros.

### Full Managed Software List

Everything below is installed and kept up to date by the playbook.

**OS packages (all profiles):**

| Abstract name     | What it is                           |
| ----------------- | ------------------------------------ |
| `git`             | version control                      |
| `curl`            | HTTP client                          |
| `ca-certificates` | root certificate bundle              |
| `stow`            | symlink farm manager                 |
| `zsh`             | shell                                |
| `tmux`            | terminal multiplexer                 |
| `neovim`          | editor                               |
| `fzf`             | fuzzy finder                         |
| `ripgrep`         | search (replaces grep)               |
| `fd`              | file finder (replaces find)          |
| `age`             | encryption                           |
| `gh`              | GitHub CLI                           |
| `delta`           | syntax-highlighted git diffs         |
| `btop`            | process viewer (replaces top/htop)   |
| `unzip`           | archive utility                      |
| `wireguard_tools` | VPN tooling                          |
| `build_tools`     | compiler toolchain (gcc, make, etc.) |
| `python`          | Python 3 + pip                       |

**OS packages (linux_desktop profile only):**

| Abstract name            | What it is                                      |
| ------------------------ | ----------------------------------------------- |
| `sway`                   | Wayland tiling compositor                       |
| `swaylock`               | screen locker                                   |
| `swayidle`               | idle management (auto-lock, display off)        |
| `swaybg`                 | wallpaper                                       |
| `waybar`                 | status bar (replaces swaybar + i3status)        |
| `grim`                   | screenshot capture                              |
| `slurp`                  | region selection for screenshots                |
| `wl_clipboard`           | Wayland clipboard (wl-copy/wl-paste)            |
| `brightnessctl`          | backlight control                               |
| `mako_notifier`          | notification daemon                             |
| `xdg_desktop_portal`     | desktop integration                             |
| `xdg_desktop_portal_wlr` | screen sharing for Zoom/Slack/Teams             |
| `xdg_desktop_portal_gtk` | Settings portal (bridges dark mode to apps)     |
| `foot`                   | lightweight Wayland terminal (ghostty fallback) |
| `kanshi`                 | automatic display profile switching (Wayland)   |
| `pavucontrol`            | PulseAudio volume control                       |
| `pipewire`               | audio/video server (replaces PulseAudio)        |
| `wireplumber`            | PipeWire session manager                        |
| `pipewire_pulse`         | PulseAudio compatibility shim for PipeWire      |
| `pipewire_alsa`          | ALSA compatibility shim for PipeWire            |
| `pipewire_jack`          | JACK compatibility shim for PipeWire            |
| `bluez`                  | Bluetooth protocol stack                        |
| `blueman`                | GTK Bluetooth manager with tray applet          |
| `power_profiles_daemon`  | battery/balanced/performance profile switcher   |
| `plocate`                | fast file indexer (`locate`)                    |
| `upower`                 | power / battery state D-Bus service             |
| `nautilus`               | file manager (GTK4/libadwaita, dark-mode-aware) |
| `rofi`                   | application launcher                            |
| `dex`                    | XDG autostart                                   |
| `nm_applet`              | NetworkManager tray applet                      |
| `jetbrains_mono_fonts`   | terminal/editor font                            |

**OS packages (macOS via Homebrew):**

All core CLI packages above via `brew install`, plus `ansible`, `starship`. Ghostty via `brew install --cask ghostty`.

**Tailscale** (via dedicated Ansible role — adds repo on apt/dnf, installs from default repos on Arch/openSUSE).

**User-managed runtimes (~/apps):**

| Tool         | Location              | Install method              | Update method    |
| ------------ | --------------------- | --------------------------- | ---------------- |
| uv           | `~/apps/uv`           | astral.sh installer         | re-run installer |
| starship     | `~/apps/bin/starship` | starship.rs installer       | re-run installer |
| fnm          | `~/.local/share/fnm`  | fnm.vercel.app installer    | re-run installer |
| Node.js LTS  | via fnm               | `fnm install --lts`         | re-run install   |
| npm (latest) | via fnm/node          | `npm install -g npm@latest` | re-run install   |
| corepack     | via Node.js           | `corepack enable`           | ships with Node  |

**Stow packages (symlinked into $HOME):**

| Package    | What it manages                                                      |
| ---------- | -------------------------------------------------------------------- |
| `ssh`      | `~/.ssh/config`, `~/.ssh/config.local.example`                       |
| `nvim`     | `~/.config/nvim/` (includes lazy.nvim)                               |
| `tmux`     | `~/.tmux.conf`                                                       |
| `zsh`      | `~/.zshrc`, `~/.zsh_profile`, `~/.zsh_extras.example`                |
| `bin`      | `~/.local/scripts/*` (user utility scripts)                          |
| `ghostty`  | `~/.config/ghostty/`                                                 |
| `sway`     | `~/.config/sway/config`, `config.local.example` (linux_desktop only) |
| `waybar`   | `~/.config/waybar/config.jsonc` (linux_desktop only)                 |
| `mako`     | `~/.config/mako/config` (linux_desktop only)                         |
| `kanshi`   | `~/.config/kanshi/config.example` (linux_desktop only)               |
| `gtk`      | `~/.config/gtk-3.0/settings.ini`, `gtk-4.0/settings.ini` (linux_desktop only) |
| `wireplumber` | `~/.config/wireplumber/wireplumber.conf.d/` (linux_desktop only) |
| `systemd`  | `~/.config/systemd/user/` — user timers like battery-monitor (linux_desktop only) |
| `fontconfig` | `~/.config/fontconfig/fonts.conf` — web system-font fallbacks (linux_desktop only) |
| `xdg-portals` | `~/.config/xdg-desktop-portal/sway-portals.conf` — portal routing (linux_desktop only) |

**Directories created by the filesystem role:**

`~/apps`, `~/apps/bin`, `~/apps/go` (+ bin, cache, config, pkg subdirs), `~/apps/src`, `~/apps/tmp`, `~/.local/bin`, `~/.local/scripts`, `~/.local/share`, `~/.local/share/backgrounds`

### Deferred Software (Not Managed)

The following were deliberately cut to keep the base small. See the README for the full list. They can be added back via local override files (`~/.zsh_extras`, `~/.config/sway/config.local`).

- Desktop apps (Discord, IntelliJ, Obsidian, Postman, Thunderbird) — use Flatpak or JetBrains Toolbox
- Sway workspace rules (Firefox, Slack, Obsidian, JetBrains IDEA, Spotify) — in `config.local.example`
- Shell wrappers (claude, gemini, gssh, vpns/exitnode, android, dbmate/dbdump, cdwt, gcloud, cloud-sql-proxy) — in `zsh_extras.example`
- Java/Gradle — managed per-project by IntelliJ (`~/.jdks/`) and `./gradlew`; use `mise` if CLI JDK needed
- Linux packages (blueman, lxappearance)

### Future Work

Potential additions that are well-maintained and widely adopted. None are blocking.

**Shell plugins** (source directly in `.zshrc` or use a lightweight plugin manager like Antidote):

| Plugin                                                                          | Stars | What it does                                     |
| ------------------------------------------------------------------------------- | ----- | ------------------------------------------------ |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)         | ~35k  | Fish-like inline history suggestions as you type |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | ~22k  | Colors valid/invalid commands in real time       |
| [zoxide](https://github.com/ajeetdsouza/zoxide)                                 | ~28k  | Smarter `cd` — learns your frequent directories  |

**Terminal tools**:

| Tool                                                | Stars | What it does                                              |
| --------------------------------------------------- | ----- | --------------------------------------------------------- |
| [bat](https://github.com/sharkdp/bat)               | ~58k  | `cat` with syntax highlighting and line numbers           |
| [eza](https://github.com/eza-community/eza)         | ~17k  | Modern `ls` with git status, icons, tree view             |
| [lazygit](https://github.com/jesseduffield/lazygit) | ~76k  | Full TUI for git — staging, rebasing, conflict resolution |

**Tmux plugins** (via [tpm](https://github.com/tmux-plugins/tpm)):

| Plugin                                                           | Stars | What it does                         |
| ---------------------------------------------------------------- | ----- | ------------------------------------ |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | ~13k  | Persist tmux sessions across reboots |

**Neovim** (already has lazy.nvim via stow):

| Plugin                                                                | Stars | What it does                                      |
| --------------------------------------------------------------------- | ----- | ------------------------------------------------- |
| [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)    | ~19k  | Fuzzy finder for files, grep, buffers             |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | ~14k  | AST-based syntax highlighting and code navigation |

**Desktop**:

| Tool                                              | What it does                                                                         |
| ------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `ext-background-effect-v1`                        | Wayland protocol for compositor blur — merged May 2025, awaiting Sway implementation |
| [SwayFX](https://github.com/WillPower3309/swayfx) | Drop-in Sway fork with blur/shadows/rounded corners (interim option)                 |
| Keybinding cheatsheet (e.g. `Super+?`)            | Small script that greps `bindsym` from sway config and pipes to `swaynag` or `rofi -dmenu`. Discoverability for a keyboard-only desktop without adopting omarchy's full `omarchy-menu`. |
| Unified theme primitive                           | See [theming-plan.md](theming-plan.md) — single palette file drives ghostty/sway/mako/btop/nvim through stable include paths. Level 0 is a single baked-in Tokyo Night palette, ~40 LoC across existing configs. |

**Security/privacy**:

| Tool                                         | Stars | What it does                                                        |
| -------------------------------------------- | ----- | ------------------------------------------------------------------- |
| [gopass](https://github.com/gopasspw/gopass) | ~6.8k | CLI password manager, compatible with `pass`, works with GPG or age |
