# Dotfiles

This repo is the source of truth for this environment.

It now has two layers:

- `stow` packages for static files that should land in `$HOME`
- Ansible for machine bootstrap, package installation, updates, and self-healing convergence

Assumption: start from a nearly blank machine. The intended baseline is "has `curl` and the system package manager", not "already has git/ssh/ansible/stow configured".

## Install Location Policy

Software is split by ownership:

- OS package manager for general-purpose packages and desktop apps
- `~/apps` for user-scoped SDKs and runtimes that are cleaner when kept self-contained
- `~/.local/bin` for user executables and wrappers
- `~/.config`, `~/.ssh`, and related home-directory targets for config managed by `stow`

Current standard roots:

- `~/apps/uv` for `uv`, its tools, and its managed Python installs
- `~/apps/nvm` for `nvm`
- `~/apps/go` for Go workspace state, module cache, build cache, and user-installed Go binaries
- `~/.local/bin` for normal user binaries already designed to live on `PATH`

The intent is simple:

- use package-manager defaults when they are the most stable and lowest-maintenance choice
- use `~/apps` only when the tool is effectively a self-contained runtime or SDK

Current source-of-truth choices:

- package manager: `git`, `curl`, `stow`, `ansible`, `zsh`, `tmux`, `neovim`, `fzf`, `ripgrep`, `fd`, `age`, Python, and the current Linux desktop packages
- Homebrew cask: `ghostty` on macOS
- `~/apps`: `uv`, `nvm`, and Go workspace state

Neovim specifically is now package-manager-managed, not AppImage-managed.

## Entry Points

Fresh machine bootstrap from a hosted script:

```sh
curl -fsSL https://raw.githubusercontent.com/pashbyl/dotfiles/master/bootstrap.sh | sh
```

If the default repo URL or branch is wrong for the current machine, override them:

```sh
DOTFILES_REPO_URL=https://github.com/<you>/dotfiles.git \
DOTFILES_REPO_REF=master \
curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/master/bootstrap.sh | sh
```

Normal day-to-day usage inside the repo:

```sh
./scripts/apply
./scripts/update
./scripts/check
```

`./install` remains as a compatibility wrapper around `./scripts/apply`.

## What Each Command Does

- `bootstrap.sh`
  - installs the minimum prerequisites needed to become managed
  - clones or updates the repo
  - runs `scripts/apply`
- `scripts/apply`
  - idempotently converges the machine to the repo state
  - installs `ansible` and `stow` first if they are missing
  - installs missing packages
  - installs and maintains user-scoped runtimes in `~/apps`
  - installs `oh-my-zsh`
  - applies the `stow` packages
- `scripts/update`
  - does everything in `apply`
  - upgrades managed packages to latest stable
- `scripts/check`
  - runs the Ansible playbook in check mode with diff output

## Profiles

Profiles are selected automatically:

- Linux defaults to `linux_desktop`
- macOS defaults to `macos_cli`

Override the profile when needed:

```sh
DOTFILES_PROFILE=linux_desktop ./scripts/apply
DOTFILES_PROFILE=macos_cli ./scripts/update
```

## Linux Distro Support

The Linux implementation now has distro-specific package maps for the major package-manager families:

- Debian / Ubuntu and other `apt`-based distros
- Fedora and other `dnf`-based distros
- Arch and other `pacman`-based distros
- openSUSE and other `zypper`-based distros

The bootstrap scripts can install prerequisites on those systems, and Ansible maps the managed package set to distro-specific package names.

## Current Repo Layout

- `bootstrap.sh`: zero-to-managed machine bootstrap
- `scripts/`: local apply/update/check entrypoints
- `ansible/`: package management and convergence logic
- `ssh`, `zsh`, `tmux`, `bin`, `nvim`, `ghostty`, `i3`, `i3status`, `picom`: existing `stow` packages

## Managed Today

Linux desktop:

- core shell and editor tooling
- `git`, `zsh`, `tmux`, `neovim`, `fzf`, `ripgrep`, `age`
- `i3`, `i3status`, `picom`, `rofi`, `feh`, `thunar`, `pavucontrol`
- `uv` in `~/apps/uv`
- `nvm` in `~/apps/nvm` with the current Node.js LTS installed as default
- `ghostty` is the preferred terminal; Linux also installs a minimal fallback terminal so first boot is always usable
- your existing stowed shell, SSH, terminal, editor, and desktop config

macOS CLI:

- core CLI tooling via Homebrew
- Ghostty via Homebrew cask
- `uv` in `~/apps/uv`
- `nvm` in `~/apps/nvm` with the current Node.js LTS installed as default
- the same shared `stow` packages where they make sense

## Not Managed (Optional Add-Backs)

The following were deliberately cut from the first-pass managed set to keep the base small and testable. Any of these can be added back later behind profile flags or host-specific roles.

**Desktop app launchers** (the `desktops` stow package):

- Discord, IntelliJ, Obsidian, Postman, Thunderbird `.desktop` files
- Ghostty `.desktop` file (now installed via package manager)

**i3 workspace rules** removed from the shared config:

- Firefox → workspace 2
- Slack → workspace 3
- Obsidian → workspace 3
- JetBrains IDEA → workspace 5
- Spotify → workspace 10

**Shell aliases and functions**:

- `claude` / `bigclaude` (Vertex AI Claude Code wrapper)
- `gemini` (Vertex AI Gemini CLI wrapper)
- `gssh` (gcloud compute SSH helper)
- `vpns` / `exitnode` (WireGuard ↔ Tailscale VPN switcher)
- `android` (scrcpy for a specific device)
- `dbmate` / `dbdump` (database migration tooling)
- `ar` (autorandr alias)
- `cdwt` (cd to a git worktree by name)
- gcloud CLI sourcing and completions
- cloud-sql-proxy PATH entry

**Linux packages** not in the current managed set:

- `blueman` (Bluetooth manager)
- `xbacklight` (backlight control)
- `lxappearance` (GTK theme switcher)
- `autorandr` (display profile manager)

## Notes

- The repo currently assumes the remote bootstrap script is hosted on GitHub. Replace the URL if the canonical remote is different.
- Linux is treated as having a usable system package manager already available. On macOS, `bootstrap.sh` is the intended first entrypoint because it can install Homebrew before handing off.
- Package managers remain the source of truth for standard packages. `~/apps` is reserved for self-contained user-managed tooling rather than every package on the machine.
- Secrets are intentionally out of scope for plaintext git storage. Keep private keys, tokens, and machine secrets outside the repo.
- SSH supports a private machine-local include at `~/.ssh/config.local`; use [config.local.example](/home/pashbyl/projects/dotfiles/ssh/.ssh/config.local.example) as the template.
- Some application paths in the shell config are now guarded so a freshly bootstrapped machine can converge even if every optional app is not installed yet.
- Linux desktop support is richer than macOS support right now. macOS starts at CLI parity.
- The implementation history and design rationale are documented in [docs/design-history.md](/home/pashbyl/projects/dotfiles/docs/design-history.md).
