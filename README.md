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

1. Ensures `stow`, then installs any [`packages.txt`](packages.txt) extras via `omarchy pkg add` and any [`packages.aur.txt`](packages.aur.txt) extras via `omarchy pkg aur add`.
2. Reconciles dev-env tools (`uv`, `go`): drops any pacman copy and ensures the tool is on PATH via `omarchy install dev-env python` / `omarchy install dev-env go`. omarchy lands these wherever the underlying tool defaults (today Astral's `~/.local/bin/uv` and mise's `~/.local/share/mise/shims/go`); we don't hardcode that, so the reconciliation survives upstream path changes. Idempotent on a correct machine. **Caveat:** dev-env pulls "latest" at the time it runs (mise `python@latest` / `go@latest`, Astral's uv installer), so a fresh bootstrap on a different day may yield different Python/uv/go versions. Use `make update` to bump them deliberately later.
3. Encodes XDG user-dir deltas vs Omarchy's defaults: collapses `DOCUMENTS`/`MUSIC` to `$HOME` and adds the non-standard `XDG_PROJECTS_DIR=$HOME/Projects` (read by personal scripts). Templates/Public/Desktop are already collapsed by Omarchy.
4. Stows repo-owned static files into `$HOME` — only into our own namespaces, never
   Omarchy-owned files. [D-DELTA-STORAGE]
5. Upserts one **managed block** (re-anchored at end-of-file, so it loads last and wins)
   into five Omarchy-owned files:
   - `~/.bashrc` → sources `~/.config/dotfiles/shell.sh`
   - `~/.config/hypr/hyprland.conf` → `source = ~/.config/dotfiles/hypr.conf`
   - `~/.config/nvim/lua/config/keymaps.lua` → a couple of `<leader>y` clipboard maps
   - `~/.config/tmux/tmux.conf` → `source-file ~/.config/tmux/local.conf` (your tmux overlay)
   - `~/.config/waybar/style.css` → CSS rules for the personal `#memory` module + equidistant module spacing
6. Applies jq deltas to `~/.config/waybar/config.jsonc` from `waybar/deltas.jq` and restarts waybar only on real content change. [D-WAYBAR-DELTAS]
7. Validates Hyprland (`hyprctl reload && hyprctl configerrors`).

## Repo layout

```
AGENTS.md                   # concise coding-agent guidance + comment conventions (canonical for every harness)
CLAUDE.md                   # one-line `@AGENTS.md` bridge — Claude Code reads this until it learns AGENTS.md natively
install                      # the only runtime script (stow + managed integration blocks)
Makefile                     # `make` menu; `make ci` mirrors CI; `make fmt` auto-fixes
packages.txt                 # optional extra packages → omarchy pkg add
packages.aur.txt             # optional AUR packages → omarchy pkg aur add (Slack, JetBrains Toolbox, …)
bash/.config/dotfiles/       # shell.sh (ported aliases) + shell.local.sh.example
ssh/.ssh/                    # config (+ Include config.local) + config.local.example
bin/.local/bin/              # personal commands → ~/.local/bin (on PATH)
tmux/.config/tmux/local.conf # tmux overlay; install source-file's it from omarchy's tmux.conf
hypr/.config/dotfiles/       # hypr.conf override fragment + hypr.local.conf.example
waybar/deltas.jq             # personal waybar deltas (jq filters) applied to ~/.config/waybar/config.jsonc
docs/                        # HTML knowledge base + registry.json
.github/                     # CI workflow + docs-integrity checker (scripts/check_docs.py)
```

Most coding-agent harnesses (Codex, opencode, crush, Cursor, Copilot, Windsurf,
Cline, Continue.dev, Zed, JetBrains Junie, Sourcegraph Amp, Devin, Kilo) read
`AGENTS.md` natively; Claude Code reads `CLAUDE.md`, which is a one-line
`@AGENTS.md` pointer. `make ci` enforces the bridge stays correct. [F-AGENT-GUIDANCE]

The waybar config is omarchy-owned and mutated two different ways by omarchy
updates (wholesale `omarchy-refresh-waybar` + surgical `sed` migrations —
[F-WAYBAR-MIGRATIONS]). Rather than forking it (which would silently drop future
upstream additions) or editing in place (wiped on the next refresh), this repo
owns only the personal deltas as jq filters in `waybar/deltas.jq`; `install`
applies them idempotently and only restarts waybar on a real change. [D-WAYBAR-DELTAS]

## Checks (`make`)

A [`Makefile`](Makefile) is the single source of truth for repo checks, and CI
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs `make ci` —
so **green locally means green in CI**.

- `make` / `make help` — list every target
- `make ci` — full gate (shellcheck + shfmt + prettier + docs integrity); run before committing
- `make fmt` — auto-fix formatting in place (shfmt + prettier)
- `make tools` — show required tools and how to install them on Omarchy
- `make update` — refresh everything (omarchy/pacman/AUR + firmware + uv) and run `verify`
- `make verify` — read-only health check of the live overlay (hyprctl, managed blocks, stow links, dev-env tools, XDG dirs, default-tracking overrides)

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
make update          # one command for everything package-manager-reachable on the box
```

`make update` chains three things `omarchy update -y` alone doesn't cover together:

1. `omarchy update -y` — pacman + AUR + omarchy itself + migrations + keyring + orphan cleanup. May still prompt for a required restart/reboot. [F-CLI]
2. `omarchy update firmware` — `fwupdmgr` BIOS/firmware updates (NOT included in step 1).
3. `uv self update` — only if `uv` is on PATH (the Astral installer used by `omarchy install dev-env python` lives outside pacman/yay).

JetBrains IDEs managed by `jetbrains-toolbox` update via the Toolbox UI — there's no headless CLI for them — so open Toolbox separately. (The `jetbrains-toolbox` AUR package itself does update in step 1.)

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
