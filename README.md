# Dotfiles

Personal environment managed by [stow](https://www.gnu.org/software/stow/) + [Ansible](https://docs.ansible.com/). Bootstraps a near-blank machine to a fully configured Linux desktop or macOS CLI workstation.

## Quick Start

**Fresh machine** (needs only `curl` and a package manager):

```sh
curl -fsSL https://raw.githubusercontent.com/pashbyl/dotfiles/master/bootstrap.sh | sh
```

**Day-to-day** (inside the repo):

```sh
./scripts/apply     # converge to repo state
./scripts/update    # apply + upgrade everything to latest
./scripts/check     # dry-run — show what would change
```

## What Gets Installed

### Packages (via OS package manager)

| Category | Packages |
|----------|----------|
| Core CLI | `git`, `zsh`, `tmux`, `neovim`, `fzf`, `ripgrep`, `fd`, `age`, `stow` |
| Desktop (Linux) | `i3`, `i3status`, `picom`, `rofi`, `feh`, `thunar`, `pavucontrol` |
| macOS | same core CLI via Homebrew, plus Ghostty via cask |

### User-managed runtimes (in `~/apps`)

| Tool | Location | What `update` does |
|------|----------|--------------------|
| [uv](https://github.com/astral-sh/uv) | `~/apps/uv` | re-runs installer |
| [nvm](https://github.com/nvm-sh/nvm) + Node LTS | `~/apps/nvm` | pulls latest nvm, checks for newer LTS |

### Config (via stow symlinks)

`zsh`, `tmux`, `nvim`, `ssh`, `ghostty`, `i3`, `i3status`, `picom`, plus user scripts in `bin`.

### Also

- **oh-my-zsh** — managed install, auto-update disabled (Ansible handles it)
- **nvm lazy-loaded** — shell startup doesn't pay the ~300ms nvm sourcing cost

## Profiles

Auto-detected by OS. Override with:

```sh
DOTFILES_PROFILE=macos_cli ./scripts/apply
```

| Profile | Default on | Notes |
|---------|-----------|-------|
| `linux_desktop` | Linux | full desktop environment |
| `macos_cli` | macOS | CLI + terminal parity, no desktop management |

## Distro Support

Tested on:

| Distro | Package manager | Status |
|--------|----------------|--------|
| Ubuntu / Debian | apt | full pass |
| Fedora | dnf / dnf5 | full pass |
| Arch | pacman | full pass |
| openSUSE Tumbleweed | zypper | full pass |

## Repo Layout

```
bootstrap.sh          # remote entrypoint — curl | sh
scripts/              # apply, update, check
ansible/              # playbook, roles, vars, distro package maps
ssh/ zsh/ tmux/ …     # stow packages → symlinked into $HOME
docs/                 # design history and rationale
```

## SSH

Shared config lives in `ssh/.ssh/config`. Machine-specific overrides go in `~/.ssh/config.local` (gitignored, auto-included). See [`config.local.example`](ssh/.ssh/config.local.example).

## Not Managed (Optional Add-Backs)

Cut from the first-pass managed set to keep the base small. Can be added back behind profile flags or host-specific roles.

<details>
<summary>Full list of deferred items</summary>

**Desktop app launchers** — Discord, IntelliJ, Obsidian, Postman, Thunderbird `.desktop` files

**i3 workspace rules** — Firefox (ws2), Slack (ws3), Obsidian (ws3), JetBrains IDEA (ws5), Spotify (ws10)

**Shell aliases/functions** — `claude`/`bigclaude`, `gemini`, `gssh`, `vpns`/`exitnode`, `android`, `dbmate`/`dbdump`, `ar`, `cdwt`, gcloud sourcing, cloud-sql-proxy

**Linux packages** — `blueman`, `xbacklight`, `lxappearance`, `autorandr`

</details>

## Design Decisions

- Package manager for standard software; `~/apps` only for self-contained runtimes
- Stow for file placement, Ansible for everything else (packages, upgrades, convergence)
- Shared config stays generic; machine-specific values go in local override files
- Secrets stay out of the repo entirely

Full rationale and implementation history: [docs/design-history.md](docs/design-history.md)
