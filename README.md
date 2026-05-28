# Dotfiles — a minimal personal overlay on Omarchy

A small, idempotent overlay on top of [Omarchy](https://omarchy.org/) (Arch + Hyprland).
Omarchy installs and seeds the desktop; this repo layers **only** my intentional
customizations on top, using official Omarchy paths. There is one script: `install`.

> **Design docs:** open [`docs/index.html`](docs/index.html) in a browser. Start with
> **Architecture** for the ownership model, **Decisions** for the "why", **Findings** for
> verified Omarchy behavior, and **Trace** ([`docs/registry.json`](docs/registry.json)) to
> find every place a decision is recorded or enforced (grep the `D-*`/`F-*` IDs).

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

`install` is **idempotent** — run it any time (after editing a fragment, after an Omarchy
update, etc.) and the machine reconverges. [D-IDEMPOTENT]

## What `install` does

1. Ensures `stow` (and any [`packages.txt`](packages.txt) extras) via `omarchy pkg add`.
2. Stows repo-owned static files into `$HOME` — only into our own namespaces, never
   Omarchy-owned files. [D-DELTA-STORAGE]
3. Upserts one **managed block** (re-anchored at end-of-file, so it loads last and wins)
   into four Omarchy-owned files:
   - `~/.bashrc` → sources `~/.config/dotfiles/shell.sh`
   - `~/.config/hypr/hyprland.conf` → `source = ~/.config/dotfiles/hypr.conf`
   - `~/.config/nvim/lua/config/keymaps.lua` → a couple of `<leader>y` clipboard maps
   - `~/.config/tmux/tmux.conf` → `source-file ~/.config/tmux/local.conf` (your tmux overlay)
4. Validates Hyprland (`hyprctl reload && hyprctl configerrors`).

## Repo layout

```
install                      # the only runtime script (stow + managed integration blocks)
Makefile                     # `make` menu; `make ci` mirrors CI; `make fmt` auto-fixes
packages.txt                 # optional extra packages → omarchy pkg add
bash/.config/dotfiles/       # shell.sh (ported aliases) + shell.local.sh.example
ssh/.ssh/                    # config (+ Include config.local) + config.local.example
bin/.local/bin/              # personal commands → ~/.local/bin (on PATH)
tmux/.config/tmux/local.conf # tmux overlay; install source-file's it from omarchy's tmux.conf
hypr/.config/dotfiles/       # hypr.conf override fragment + hypr.local.conf.example
docs/                        # HTML knowledge base + registry.json
.github/                     # CI workflow + docs-integrity checker (scripts/check_docs.py)
```

## Checks (`make`)

A [`Makefile`](Makefile) is the single source of truth for repo checks, and CI
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs `make ci` —
so **green locally means green in CI**.

- `make` / `make help` — list every target
- `make ci` — full gate (shellcheck + shfmt + prettier + docs integrity); run before committing
- `make fmt` — auto-fix formatting in place (shfmt + prettier)
- `make tools` — show required tools and how to install them on Omarchy

Tooling is Omarchy-native: `omarchy pkg add shfmt shellcheck` (or the leaner
`omarchy pkg aur add shellcheck-bin`); prettier runs via `npx` (pinned), the docs
checker via system `python3`.

## Machine-local overrides (gitignored)

Copy the `.example` files and fill in per-machine/secret values; they are sourced
automatically and never committed. [D-SECRETS-LOCAL]

| Copy this | To | For |
| --- | --- | --- |
| `bash/.config/dotfiles/shell.local.sh.example` | `~/.config/dotfiles/shell.local.sh` | secrets, project IDs, device serials |
| `ssh/.ssh/config.local.example` | `~/.ssh/config.local` | machine-specific ssh hosts |
| `hypr/.config/dotfiles/hypr.local.conf.example` | `~/.config/dotfiles/hypr.local.conf` | device-specific Hyprland (e.g. mouse accel) — re-run `./install` after creating |

## Updates (manual — no script) [D-SCRIPTS-MINIMAL]

```sh
omarchy update -y    # all packages to latest stable + migrations + AUR; skips the menu.
                     # May still prompt for a required restart/reboot. [F-CLI]
```

If an Omarchy refresh/migration ever strips one of the managed blocks, just re-run `./install`.

## One-time migration cleanup (manual)

After confirming the new setup works, remove the old i3/zsh leftovers:

```sh
rm -rf ~/.config/i3 ~/.config/i3status ~/.config/picom ~/.oh-my-zsh ~/.zshrc ~/.zsh_profile
# old bin/ stowed to ~/.local/scripts; it now lives in ~/.local/bin, so drop the stale dir:
rm -rf ~/.local/scripts
# plus any leftover broken symlinks from the old stow setup:
#   find ~ -maxdepth 3 -xtype l -lname '*dotfiles*' -print   # review, then -delete
```

## What this repo deliberately does **not** manage

Omarchy owns these; tracking them would fight upstream updates: the seeded Hyprland files
(`hyprland.conf`, `bindings.conf`, …), the Neovim config tree, waybar/walker/terminal
configs, themes, and `~/.config/omarchy/current/`. See `docs/decisions.html`. [D-CARRY-SET]
