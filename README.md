# Dotfiles — a minimal personal overlay on Omarchy

A small, idempotent overlay on top of [Omarchy](https://omarchy.org/)
(Arch + Hyprland). Omarchy installs and seeds the desktop; this repo
layers my customizations on top via official paths. One script: `install`.
[D-SCRIPTS-MINIMAL]

> **Design docs:** open [`docs/index.html`](docs/index.html) for
> architecture, decisions, findings, and traceability. This README is
> the usage surface only.

## Quick start

```sh
# 1. Install Omarchy.
# 2. Run "Remove Preinstalled" from the Omarchy menu (Super + Alt + Space → Remove).
#    This repo's baseline is the post-Remove-Preinstalled state. [D-BASELINE][F-BASELINE]
# 3. Clone and install:
git clone <this-repo> ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install
# 4. Open a new shell (or `exec bash`) to load shell changes.
```

`install` is idempotent — re-run after editing a fragment, after an
Omarchy refresh, or to drop newly-added entries in `packages.remove.txt`.
[D-IDEMPOTENT][D-PKG-REMOVE]

## Daily use

| Command         | What it does                                                |
| ---             | ---                                                         |
| `./install`     | Re-converge the overlay                                     |
| `make ci`       | Lint + format check + docs integrity (run before committing) |
| `make fmt`      | Auto-fix formatting (shfmt + prettier)                       |
| `make verify`   | Live overlay health check (read-only)                       |
| `make update`   | omarchy + firmware + uv update, then `make verify`           |

## Per-machine overrides

Copy each `.example` and fill in secrets/host values; the real files are
gitignored and sourced automatically. [D-SECRETS-LOCAL]

| Copy this                                       | To                                       | For                                                                                          |
| ---                                             | ---                                      | ---                                                                                          |
| `bash/.config/dotfiles/shell.local.sh.example`  | `~/.config/dotfiles/shell.local.sh`      | secrets, project IDs, device serials                                                         |
| `ssh/.ssh/config.local.example`                 | `~/.ssh/config.local`                    | machine-specific ssh hosts                                                                   |
| `hypr/.config/dotfiles/hypr.local.conf.example` | `~/.config/dotfiles/hypr.local.conf`     | device-specific Hyprland (e.g. mouse accel) — re-run `./install` after creating              |

## Updates

```sh
make update
```

Chains `omarchy update -y` (pacman + AUR + omarchy migrations) +
`omarchy update firmware` (fwupd) + `uv self update`, then `make verify`.
Each step is warn-on-failure so a non-zero exit doesn't silently skip the
rest. [F-CLI]
