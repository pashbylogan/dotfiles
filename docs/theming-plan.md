# Cross-App Theming — Research & Phased Plan

Deferred design note. Read this before implementing unified theming. Not
implemented in the repo yet.

## Why this exists

Omarchy's "one command re-themes the whole desktop" feature is the visible
part of its polish. We looked at how it works and decided against adopting the
full engine (too opinionated, too much surface area) but want to capture the
design so a lightweight version can be shipped later if we want it.

The insight worth keeping:

> Apps don't need a theme engine. They need a stable file path. Once every
> app reads from `~/.config/dotfiles-theme/current/<app>.conf`, "one command
> re-themes the desktop" reduces to a `mv`. That's 90% of the magic with 10%
> of the code.

## How omarchy's theme system works

Source: [basecamp/omarchy](https://github.com/basecamp/omarchy), `dev` branch.
Relevant paths: `themes/`, `default/themed/`, `bin/omarchy-theme-*`.

Three primitives do all the work.

### 1. Palette file as single source of truth

Every theme is a directory. Example: `themes/tokyo-night/`:

```
colors.toml        # ~20 k=v hex pairs: background, foreground, accent,
                   # cursor, selection_*, color0..color15
backgrounds/       # wallpapers
preview.png
btop.theme         # pre-baked (not templated) app configs
icons.theme
keyboard.rgb
neovim.lua         # LazyVim plugin spec: colorscheme = "tokyonight-night"
vscode.json        # {"name": "Tokyo Night", "extension": "enkia.tokyo-night"}
```

### 2. Template engine (~60 lines of sed)

`default/themed/<app>.conf.tpl` holds a generic config with `{{ background }}`
etc. `omarchy-theme-set-templates` builds a sed script from `colors.toml` and
emits three variants per key: `{{ key }}` (raw hex), `{{ key_strip }}` (no
`#`), `{{ key_rgb }}` (decimal `r,g,b`). No jinja, no yq — just sed.

Template coverage: alacritty, ghostty, kitty, btop, mako, hyprland, hyprlock,
walker CSS, waybar CSS, swayosd CSS, chromium theme color, obsidian CSS.

Rule: if the app reads a plain-text config, use a `.tpl`. If the app has a
richer format (JSON settings, colorscheme plugin), pre-bake a per-theme file
instead of templating.

### 3. "Current theme" symlink + atomic swap

Every app's config points at a stable path:

```
~/.config/omarchy/current/theme  -> symlink, rotated on each swap
~/.config/mako/config            -> ../omarchy/current/theme/mako.ini
~/.config/btop/themes/current.theme -> ../omarchy/current/theme/btop.theme
```

`omarchy-theme-set <name>` stages everything into
`~/.config/omarchy/current/next-theme/`, runs the template engine, then:

```
rm -rf current/theme
mv next-theme current/theme
```

`mv -T` on a directory symlink is atomic. After the swap it SIGHUPs the apps
that need a reload (`makoctl reload`, restart waybar, reload ghostty) and
writes `current/theme.name` so the name survives restart.

### 4. External-app tier (separate scripts per app)

For apps that don't read a flat file:

- **VS Code / Cursor / Codium** — `code --install-extension <ext>`, then sed
  `workbench.colorTheme` in `settings.json`. Skippable via a toggle file.
- **Obsidian** — parse `~/.config/obsidian/obsidian.json`, copy `obsidian.css`
  into each vault's `.obsidian/themes/Omarchy/theme.css`.
- **Chromium / Brave** — write `/etc/<browser>/policies/managed/color.json`
  with `BrowserThemeColor`, then `--refresh-platform-policy`.
- **GNOME / libadwaita** — `gsettings set …/interface/color-scheme`,
  `gtk-theme`, `icon-theme`.
- **Neovim (LazyVim)** — drop `neovim.lua` into plugin specs; restart nvim.

## Phased plan for this repo

Do them in order. Stop when the next level stops being worth it. Resist
adding flexibility before a second or third theme actually exists.

### Level 0 — single baked-in palette (~2 hours)

One new stow package containing pre-rendered per-app snippets. No engine, no
switcher. Each app's main config `include`s the theme file.

```
theme/.config/dotfiles-theme/
  sway.conf        # client.focused / unfocused, border colors
  mako.ini         # theme-adjacent keys only (text/border/background color)
  ghostty.conf     # palette = 0=#… lines
  btop.theme
  waybar.css       # optional — only if/when waybar gets a stylesheet
  nvim-colorscheme # plain text: "tokyonight-night"
```

App wiring (one line per app):

```conf
# sway
include ~/.config/dotfiles-theme/sway.conf

# mako
include ~/.config/dotfiles-theme/mako.ini

# ghostty
config-file = ~/.config/dotfiles-theme/ghostty.conf

# btop: symlink theme file, set color_theme = "dotfiles-theme"
# nvim: one plugin file that reads nvim-colorscheme and passes it to LazyVim
```

Outcome: single place where palette changes happen. No switcher yet, no
engine. This is where most of the real day-to-day value lives.

### Level 1 — multi-theme with atomic switcher (~half day on top of L0)

Only once we actually want a second palette.

```
theme/.config/dotfiles-theme/themes/
  tokyo-night/{sway.conf, mako.ini, ghostty.conf, btop.theme, nvim-colorscheme, …}
  gruvbox/{same files}
  nord/{same files}

# managed outside stow, gitignored (like our kanshi pattern):
~/.config/dotfiles-theme/current -> ../themes/tokyo-night
```

App configs change one line each:

```conf
include ~/.config/dotfiles-theme/current/sway.conf
```

New script at `bin/.local/scripts/theme-set`:

```bash
#!/bin/sh
set -eu
name=$1
target="$HOME/.config/dotfiles-theme/themes/$name"
[ -d "$target" ] || { echo "unknown theme: $name"; exit 1; }
ln -sfn "$target" "$HOME/.config/dotfiles-theme/current.next"
mv -T "$HOME/.config/dotfiles-theme/current.next" "$HOME/.config/dotfiles-theme/current"
makoctl reload 2>/dev/null || true
pkill -SIGUSR2 waybar 2>/dev/null || true
swaymsg reload 2>/dev/null || true
echo "$name" > "$HOME/.config/dotfiles-theme/name"
```

`mv -T` on a symlink is atomic — this is omarchy's staging trick in 10 lines.

Gets us omarchy's *perceived* "one command re-themes 5 apps" with zero
template engine and zero per-app restart scripts. At 3–5 themes × 5–7 apps
(15–35 small files, pure text, reviewable), the duplication is cheap.

### Level 2 — palette file + template engine (probably skip)

Only worth it at >5 themes or >8 apps. The omarchy engine is ~60 lines of
sed — trivial to port — but adds a moving part contributors have to learn
before they can ship a theme. **Don't do this preemptively.** Re-evaluate if
and when Level 1's duplication starts to bite.

### Level 3 — external-app coupling (skip entirely)

- **VS Code / JetBrains surgery** — `design-history.md` already puts desktop
  apps outside this repo's scope. Leave them self-themed.
- **Obsidian vault CSS injection** — invasive, breaks sync, low ROI.
- **Chromium managed policies** — requires root writes to
  `/etc/chromium/policies/managed/` and only colors the browser chrome.
  Not worth the complexity.
- **GNOME / libadwaita** — we already set `color-scheme=prefer-dark` in the
  `desktop_linux` role. If we ever want accent-color sync (libadwaita 1.6+),
  the `desktop_linux` role is the right place, not a theme role.

## Integration points with PR #1

Level 0 is reachable today with ~40 lines of edits across these files:

| File | Change |
|------|--------|
| `theme/.config/dotfiles-theme/` (new) | Add the stow package with one baseline palette |
| `ansible/group_vars/all.yml` | Add `theme` to `dotfiles_stow_packages_linux_desktop` |
| `sway/.config/sway/config` | Replace `client.focused` line with `include ~/.config/dotfiles-theme/sway.conf` |
| `mako/.config/mako/config` | Move `border-color` / `background-color` / `text-color` to a separate theme file, `include` it |
| `ghostty/.config/ghostty/config` | Replace `theme = tokyonight` with `config-file = ~/.config/dotfiles-theme/ghostty.conf` |
| `nvim/.config/nvim/lua/plugins/` | New `colorscheme.lua` that reads `~/.config/dotfiles-theme/nvim-colorscheme` and passes it to LazyVim's `opts.colorscheme` |
| `btop` (new stow package or ansible role write) | Symlink `~/.config/btop/themes/dotfiles-theme.theme` → `~/.config/dotfiles-theme/btop.theme`, set `color_theme = "dotfiles-theme"` in `btop.conf` |
| `docs/design-history.md` | New section (28?): "Unified theme primitive, not a full theme engine" |

Baseline palette suggestion: Tokyo Night, to preserve visual continuity with
the current ghostty `theme = tokyonight` default.

## Decision record — what to explicitly not copy

To keep `docs/design-history.md` §22–27 principles intact:

- Omarchy's `omarchy-menu` + walker/elephant launcher stack — rofi already
  covers the niche; menu is opinionated UI surface we don't want to own.
- Omarchy's theme switcher as a top-level command bound to `SUPER SHIFT CTRL
  SPACE` — wait until we have more than one theme.
- VS Code / Obsidian / Chromium runtime theme sync — out of scope for this
  repo per existing "desktop apps aren't managed here" rule.
- Plymouth / SDDM branding — we chose TTY + `exec sway`; don't un-choose it
  for visual polish.

## References

- omarchy: https://github.com/basecamp/omarchy
- Key files:
  - `bin/omarchy-theme-set` — orchestrator
  - `bin/omarchy-theme-set-templates` — ~60-line sed engine
  - `default/themed/*.tpl` — templates
  - `themes/tokyo-night/colors.toml` — example palette
