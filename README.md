# Dotfiles

Personal environment managed by [stow](https://www.gnu.org/software/stow/) + [Ansible](https://docs.ansible.com/). Bootstraps a near-blank Fedora Linux machine to a fully configured desktop workstation.

## Quick Start

**Fresh machine** (needs only `curl` or `wget` and a package manager):

```sh
curl -fsSL https://raw.githubusercontent.com/pashbylogan/dotfiles/master/bootstrap.sh | sh
# or
wget -qO- https://raw.githubusercontent.com/pashbylogan/dotfiles/master/bootstrap.sh | sh
```

**Day-to-day** (from anywhere — `~/.local/scripts` is on PATH after first apply):

```sh
dot-apply     # converge to repo state
dot-update    # apply + upgrade everything to latest
dot-check     # dry-run — show what would change
dot-cleanup   # remove replaced packages, orphaned system paths + home configs (optional, interactive)
```

**After first install** — one-time manual steps:

```sh
# Git identity
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# SSH key (if not migrated from another machine)
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
# Add that public key to GitHub, then verify push auth:
ssh -T git@github.com

# Tailscale
sudo tailscale up

# GitHub CLI
gh auth login

# Optional: gcloud CLI (if using GCP)
# gcloud auth login

# Optional: copy local overrides from examples
cp ~/projects/dotfiles/sway/.config/sway/config.local.example ~/.config/sway/config.local
cp ~/projects/dotfiles/zsh/.zsh_extras.example ~/.zsh_extras

# Optional: TPM2 auto-unlock for root LUKS, keeping your passphrase as fallback
luks-tpm2-unlock status
luks-tpm2-unlock enable
```

## What Gets Installed

### Packages (via OS package manager)

| Category        | Packages                                                                                                                               |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Core CLI        | `git`, `zsh`, `tmux`, `neovim`, `fzf`, `ripgrep`, `fd`, `age`, `gh`, `delta`, `btop`, `jq`, `rsync`, `netcat`, `lsof`, `patch`, `stow`, `golang` |
| Desktop (Wayland stack) | `sway`, `swaylock`, `swayidle`, `swaybg`, `kanshi`, `waybar`, `swayosd`, `rofi`, `grim`, `slurp`, `wl-clipboard`, `brightnessctl`, `mako`, `foot`, `ghostty`, `playerctl`, `xdg-desktop-portal{,-wlr,-gtk}` |
| Desktop (apps + services) | `nautilus`, `gvfs-{mtp,smb,nfs}`, `ffmpegthumbnailer`, `glycin-thumbnailer`, `mpv`, `imv`, `mate-polkit`, `gnome-keyring`, `pavucontrol`, `pipewire`, `wireplumber`, `pipewire-{pulseaudio,alsa,jack-audio-connection-kit}`, `alsa-ucm`, `bluez`, `blueman`, `NetworkManager-wifi`, `nm-applet`, `power-profiles-daemon`, `plocate`, `upower`, `dconf`, `python3-psutil`, `zram-generator-defaults` |
| Fonts & icons   | `cascadia-mono-nf-fonts`, `google-noto-color-emoji-fonts`, `google-noto-sans-cjk-vf-fonts`, `adwaita-icon-theme` |
| Networking      | `wireguard-tools`, `tailscale`                                                                                                         |

### User-managed runtimes (in `~/apps`)

| Tool                                            | Location              | What `update` does                      |
| ----------------------------------------------- | --------------------- | --------------------------------------- |
| [uv](https://github.com/astral-sh/uv)           | `~/apps/uv`           | re-runs installer                       |
| [fnm](https://github.com/Schniz/fnm) + Node LTS | `~/apps/fnm`          | re-runs installer, checks for newer LTS |
| [Starship](https://starship.rs)                 | `~/apps/bin/starship` | re-runs installer                       |

### Config (via stow symlinks)

`zsh`, `tmux`, `nvim`, `ssh`, `ghostty`, `sway`, `waybar`, `mako`, `kanshi`, `gtk`, `wireplumber`, `systemd` (user timers), `fontconfig`, `xdg-portals`, plus user-callable scripts in `bin/` (→ `~/.local/scripts/`, on PATH) and unit-internal helpers in `lib/` (→ `~/.local/lib/dotfiles/`, off PATH — addressed by absolute path from systemd units, sway, waybar).

### Also

- **[Starship](https://starship.rs)** prompt — Rust binary, ~2ms init, git-aware
- **[fnm](https://github.com/Schniz/fnm)** — Rust-based Node version manager, <1ms shell init
- **corepack** enabled — `pnpm`/`yarn` available on-demand per-project, no global install

## Profiles

Only one profile is supported:

| Profile         | Default on | Notes                              |
| --------------- | ---------- | ---------------------------------- |
| `linux_desktop` | Linux      | Sway (Wayland) desktop environment |

## Linux Support

Linux support is intentionally scoped to Fedora only:

| Distro | Package manager | Status    |
| ------ | --------------- | --------- |
| Fedora | dnf / dnf5      | full pass |

## Repo Layout

```
bootstrap.sh          # remote entrypoint — curl | sh
bin/                  # stow package → ~/.local/scripts (on PATH)
                      #   dot-apply, dot-update, dot-check, dot-cleanup
                      #   personal user commands (dev, myip, tmux-sessionizer, …)
lib/                  # stow package → ~/.local/lib/dotfiles (off PATH)
                      #   helpers called by systemd/sway/waybar by absolute path
ansible/              # playbook, roles, vars, Fedora package map
ssh/ zsh/ tmux/ …     # stow packages → symlinked into $HOME
docs/                 # design history and rationale
```

The `bin/` vs `lib/` split mirrors the Linux FHS distinction between `/usr/bin` (user-callable, on PATH) and `/usr/libexec` (internal helpers, off PATH). Anything you'd type at the shell goes in `bin/`; anything invoked only by another program (a systemd unit, a Waybar exec, a sway exec, an OS udev rule) goes in `lib/`. Keeps PATH clean and tab-completion meaningful.

## Machine-Local Overrides

Shared config stays generic in the repo. Machine-specific values go in local files that are gitignored and auto-included:

| What                              | Local file                              | Example                                                          |
| --------------------------------- | --------------------------------------- | ---------------------------------------------------------------- |
| SSH hosts                         | `~/.ssh/config.local`                   | [`config.local.example`](ssh/.ssh/config.local.example)          |
| Shell aliases/functions           | `~/.zsh_extras`                         | [`zsh_extras.example`](zsh/.zsh_extras.example)                  |
| Sway workspace/input/output rules | `~/.config/sway/config.local`           | [`config.local.example`](sway/.config/sway/config.local.example) |
| Desktop launchers                 | `~/.local/share/applications/*.desktop` | manage via Flatpak or directly                                   |

## Migrating From the Old Setup

If you previously used the old `install` script with i3, run these steps before `dot-apply`:

```sh
# 1. Preserve desktop launchers (old stow symlinks → real files)
cd ~/.local/share/applications
for f in *.desktop; do
  [ -L "$f" ] && cp --remove-destination "$(readlink -f "$f")" "$f"
done

# 2. Unstow old packages (run BEFORE pulling this branch — the source dirs
# are deleted in the new state, so `stow -D` won't find them afterward)
cd ~/projects/dotfiles
for pkg in i3 i3status picom desktops; do stow -D "$pkg" 2>/dev/null; done

# 3. Move SSH hosts to config.local
# Copy your Host entries from ~/.ssh/config into ~/.ssh/config.local

# 4. Move personal aliases to ~/.zsh_extras
cp ~/projects/dotfiles/zsh/.zsh_extras.example ~/.zsh_extras
# Edit and uncomment what you need

# 5. Move workspace rules to sway config.local
mkdir -p ~/.config/sway
cp ~/projects/dotfiles/sway/.config/sway/config.local.example ~/.config/sway/config.local
# Edit and uncomment what you need
```

## Not Managed (Optional Add-Backs)

Cut from the first-pass managed set to keep the base small. Can be added back via the local override files above.

<details>
<summary>Full list of deferred items</summary>

**Desktop app launchers** — Discord, IntelliJ, Obsidian, Postman, Thunderbird (use Flatpak or JetBrains Toolbox)

**Sway workspace rules** — Firefox (ws2), Slack (ws3), Obsidian (ws3), JetBrains IDEA (ws5), Spotify (ws10)

**Shell aliases/functions** — `claude`/`bigclaude`, `gemini`, `gssh`, `vpns`/`exitnode`, `android`, `dbmate`/`dbdump`, `cdwt`, gcloud sourcing, cloud-sql-proxy

**Linux packages** — `lxappearance` (we set GTK preferences via dconf instead)

**Docker + Docker Compose** — follow the official per-OS install guide: https://docs.docker.com/engine/install/ (Compose ships as the `docker compose` plugin)

</details>

## Design Decisions

- Package manager for standard software; `~/apps` only for self-contained runtimes
- Sway (Wayland) for the desktop — no X11 compositor, input scripts, or separate lock daemon needed
- Stow for file placement, Ansible for everything else (packages, upgrades, convergence)
- Shared config stays generic; machine-specific values go in local override files
- Secrets stay out of the repo entirely
- Packages are never auto-removed — old packages stay harmlessly until the next clean OS install. Each new machine only gets what's declared.

Full rationale and implementation history: [docs/design-history.md](docs/design-history.md)
