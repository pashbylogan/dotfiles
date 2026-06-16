#!/usr/bin/env bash
# Read-only live-machine check; failures should be reconcilable with ./install.
# [D-CI][D-IDEMPOTENT][D-DELTA-STORAGE][F-HYPR-SEAM]

set -u

REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"

# ── output helpers ───────────────────────────────────────────────────────────
# Shared palette + managed-block marker contract; single source of truth in lib/style.sh.
# shellcheck source=lib/style.sh
. "$REPO/lib/style.sh"

fails=0
pass() { printf '  %s✓%s %s\n' "$GREEN" "$NC" "$1"; }
miss() {
  printf '  %s✗%s %s\n' "$RED" "$NC" "$1"
  fails=$((fails + 1))
}
skip() { printf '  %s- skipped: %s%s\n' "$DIM" "$1" "$NC"; }
# Anchor the $HOME rewrite so /home/userN-backup does not become ~-backup.
pretty() {
  # The printed "~" is display text, not a tilde-expansion target.
  # shellcheck disable=SC2088
  case "$1" in
    "$HOME"/*) printf '%s' "~/${1#"$HOME"/}" ;;
    "$HOME") printf '%s' "~" ;;
    *) printf '%s' "$1" ;;
  esac
}

# ── Hyprland config ──────────────────────────────────────────────────────────
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
  errs="$(hyprctl configerrors 2>&1 || true)"
  if [ -z "${errs//[[:space:]]/}" ] || printf '%s' "$errs" | grep -qiF 'no error'; then
    pass "hyprctl: no config errors"
  else
    miss "hyprctl: config errors — run 'hyprctl configerrors'"
  fi
else
  skip "hyprctl (Hyprland not running in this session)"
fi

# ── managed blocks ───────────────────────────────────────────────────────────
check_block() {
  local file="$1" marker
  # Same builder install writes with (lib/style.sh), so a miss is an absent block, not marker drift.
  marker="$(managed_marker begin "$2" "$3" "${4:-}")"
  if [ -f "$file" ] && grep -qxF -- "$marker" "$file"; then
    pass "$(pretty "$file") managed block present"
  else
    miss "$(pretty "$file") managed block missing — re-run ./install"
  fi
}
check_block "$HOME/.bashrc" shell '#'
check_block "$HOME/.config/hypr/hyprland.conf" hypr '#'
check_block "$HOME/.config/nvim/lua/config/keymaps.lua" keymaps '--'
check_block "$HOME/.config/tmux/tmux.conf" tmux '#'
check_block "$HOME/.config/waybar/style.css" waybar '/*' ' */'
check_block "$HOME/.config/alacritty/alacritty.toml" alacritty '#'
check_block "$HOME/.config/starship.toml" starship-venv '#'

# ── starship venv reference ──────────────────────────────────────────────────
# The starship-venv block only renders if the format scalar references it; the
# block check above can't see that in-place edit, so grep for it. Drift (e.g. a
# refreshed Omarchy default dropping the $character anchor) → re-run ./install.
# [D-STARSHIP-VENV]
STARSHIP_TOML="$HOME/.config/starship.toml"
# ${custom.venv} is a literal starship token grep must match, not an expansion.
# shellcheck disable=SC2016
if [ ! -f "$STARSHIP_TOML" ]; then
  skip "starship venv reference ($(pretty "$STARSHIP_TOML") not present)"
elif grep -qF '${custom.venv}' "$STARSHIP_TOML"; then
  pass "starship format references the venv module (\${custom.venv})"
else
  miss "starship format missing \${custom.venv} — venv won't show; re-run ./install"
fi
unset STARSHIP_TOML

# ── stow links ───────────────────────────────────────────────────────────────
check_link() {
  local link="$1" resolved
  if [ ! -L "$link" ]; then
    miss "$(pretty "$link") is not a symlink (expected stow link into the repo)"
    return
  fi
  resolved="$(readlink -f "$link" 2>/dev/null || true)"
  # `readlink -f` resolves dangling links, so test target existence separately.
  if [ ! -e "$link" ]; then
    miss "$(pretty "$link") is a dangling symlink -> $resolved"
    return
  fi
  case "$resolved" in
    "$REPO"/*) pass "$(pretty "$link") -> repo" ;;
    *) miss "$(pretty "$link") is a symlink but doesn't resolve into the repo ($resolved)" ;;
  esac
}
check_link "$HOME/.config/dotfiles/shell.sh"
check_link "$HOME/.config/dotfiles/hypr.conf"
check_link "$HOME/.config/dotfiles/nvim.lua"
check_link "$HOME/.config/uwsm/env.d/dotfiles.sh"
check_link "$HOME/.ssh/config"
check_link "$HOME/.config/tmux/local.conf"
check_link "$HOME/.config/omarchy/hooks/theme-set.d/brave-origin-stable"
check_link "$HOME/.claude/statusline-command.sh"

# ── claude code ──────────────────────────────────────────────────────────────
# statusline is stowed (checked above); settings.json is jq-overlaid in place. Re-
# run the overlay filter and check it's a no-op — that's exactly what install
# asserts, so it covers every managed key and scales with the filter. [D-CLAUDE-CONFIG]
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ ! -f "$CLAUDE_SETTINGS" ]; then
  miss "$(pretty "$CLAUDE_SETTINGS") missing — re-run ./install"
elif [ "$(jq -f "$REPO/claude/settings.jq" "$CLAUDE_SETTINGS" 2>/dev/null)" = "$(cat "$CLAUDE_SETTINGS")" ]; then
  pass "claude settings overlay fully applied (settings.jq is a no-op)"
else
  miss "claude settings overlay drifted — re-run ./install"
fi
unset CLAUDE_SETTINGS

# ── browser default ──────────────────────────────────────────────────────────
# install uses Omarchy's package, theming, and hook surfaces until Omarchy's
# browser commands map brave-origin to stable. [D-BROWSER-DEFAULT]
BRAVE_ORIGIN_DESKTOP="brave-origin.desktop"
if [ -f "$HOME/.local/share/applications/$BRAVE_ORIGIN_DESKTOP" ] ||
  [ -f "$HOME/.nix-profile/share/applications/$BRAVE_ORIGIN_DESKTOP" ] ||
  [ -f "/usr/share/applications/$BRAVE_ORIGIN_DESKTOP" ]; then
  pass "Brave Origin desktop entry present"
else
  miss "Brave Origin desktop entry missing — re-run ./install"
fi

if current_browser="$(xdg-settings get default-web-browser 2>/dev/null)"; then
  if [ "$current_browser" = "$BRAVE_ORIGIN_DESKTOP" ]; then
    pass "Brave Origin is the default browser"
  else
    miss "default browser is $current_browser, expected $BRAVE_ORIGIN_DESKTOP — re-run ./install"
  fi
else
  skip "default browser (xdg-settings unavailable or unusable)"
fi

if pacman -Qq brave-origin-beta-bin >/dev/null 2>&1; then
  miss "brave-origin-beta-bin still installed — re-run ./install"
else
  pass "Brave Origin Beta package absent"
fi

if [ -e "$HOME/.config/brave-origin-beta-flags.conf" ]; then
  miss "$(pretty "$HOME/.config/brave-origin-beta-flags.conf") remains — re-run ./install"
else
  pass "Brave Origin Beta flags absent"
fi

if [ -f "$HOME/.config/mimeapps.list" ] && grep -qF 'brave-origin-beta.desktop' "$HOME/.config/mimeapps.list"; then
  miss "$(pretty "$HOME/.config/mimeapps.list") still references brave-origin-beta.desktop — re-run ./install"
else
  pass "mimeapps has no Brave Origin Beta references"
fi
unset BRAVE_ORIGIN_DESKTOP current_browser

# ── webapp launchers ─────────────────────────────────────────────────────────
# install reproduces omarchy's Zoom webapp launcher; flag if it drifted away
# (e.g. Remove Preinstalled / `omarchy webapp remove`) — re-run ./install. [D-WEBAPP]
if [ -f "$HOME/.local/share/applications/Zoom.desktop" ]; then
  pass "Zoom webapp launcher present"
else
  miss "Zoom webapp launcher missing — re-run ./install"
fi

# ── ssh-agent socket ─────────────────────────────────────────────────────────
# The UWSM SSH_AUTH_SOCK export is dead unless this unit is enabled. [F-SSH-AGENT]
if state=$(systemctl --user is-enabled ssh-agent.socket 2>/dev/null); then
  pass "ssh-agent.socket $state"
elif [ -z "${state:-}" ]; then
  skip "ssh-agent.socket (systemd user manager not reachable)"
else
  miss "ssh-agent.socket $state — run 'systemctl --user enable --now ssh-agent.socket' (F-SSH-AGENT)"
fi

# ── dev-env tools ────────────────────────────────────────────────────────────
# Dev-env tool paths can move; ownership contract matters more than location.
# Report pacman ownership first because ./install can reconcile that drift.
check_tool() {
  local tool="$1" current
  if pacman -Qq "$tool" >/dev/null 2>&1; then
    miss "$tool is owned by pacman — should be dev-env-managed; re-run ./install"
    return
  fi
  current="$(command -v "$tool" 2>/dev/null || true)"
  if [ -n "$current" ]; then
    pass "$tool on PATH ($(pretty "$current"))"
  else
    miss "$tool not on PATH — re-run ./install"
  fi
}
check_tool uv
check_tool go

# ── XDG user dirs ────────────────────────────────────────────────────────────
# Match literal $HOME values and accept optional trailing slash because
# xdg-user-dirs versions differ when a key collapses exactly to $HOME.
check_xdg() {
  local key="$1" expected="$2" file="$HOME/.config/user-dirs.dirs" alt=""
  case "$expected" in
    */) alt="${expected%/}" ;;
  esac
  if [ -f "$file" ] && {
    grep -qxF -- "${key}=\"${expected}\"" "$file" ||
      { [ -n "$alt" ] && grep -qxF -- "${key}=\"${alt}\"" "$file"; }
  }; then
    pass "XDG $key = $expected"
  else
    miss "XDG $key != $expected — re-run ./install"
  fi
}
# shellcheck disable=SC2016
check_xdg XDG_DOCUMENTS_DIR '$HOME/'
# shellcheck disable=SC2016
check_xdg XDG_MUSIC_DIR '$HOME/'
# shellcheck disable=SC2016
check_xdg XDG_PROJECTS_DIR '$HOME/Projects'

# ── default-tracking overrides ───────────────────────────────────────────────
# The border_size overlay deliberately re-states an Omarchy default to beat the
# window-no-gaps toggle; fail if upstream changes that default. [D-LOOKNFEEL]
check_default_match() {
  local label="$1" repo_file="$2" omarchy_file="$3" key="$4"
  if [ ! -f "$omarchy_file" ]; then
    skip "$label default-tracking ($(pretty "$omarchy_file") not present)"
    return
  fi
  if [ ! -f "$repo_file" ]; then
    skip "$label default-tracking ($(pretty "$repo_file") not present)"
    return
  fi
  # Pre-strip comment lines so a `# example: key = N` line above the real
  # setting can't shadow it. The regex is then applied to live config lines.
  local repo_val omarchy_val
  repo_val=$(grep -v '^[[:space:]]*#' "$repo_file" | grep -oE "${key}[[:space:]]*=[[:space:]]*[0-9A-Za-z_-]+" | head -1 | awk -F= '{gsub(/[[:space:]]/,"",$2); print $2}')
  omarchy_val=$(grep -v '^[[:space:]]*#' "$omarchy_file" | grep -oE "${key}[[:space:]]*=[[:space:]]*[0-9A-Za-z_-]+" | head -1 | awk -F= '{gsub(/[[:space:]]/,"",$2); print $2}')
  if [ -z "$repo_val" ] || [ -z "$omarchy_val" ]; then
    miss "$label could not be extracted (repo='$repo_val' omarchy='$omarchy_val')"
  elif [ "$repo_val" = "$omarchy_val" ]; then
    pass "$label tracks omarchy default ($repo_val)"
  else
    miss "$label drift: overlay=$repo_val, omarchy default=$omarchy_val — update both together"
  fi
}
check_default_match \
  "border_size" \
  "$REPO/hypr/.config/dotfiles/hypr.conf" \
  "$HOME/.local/share/omarchy/default/hypr/looknfeel.conf" \
  border_size

# ── summary ──────────────────────────────────────────────────────────────────
echo
if [ "$fails" -gt 0 ]; then
  printf '%sverify: %d check(s) failed%s — re-run ./install to reconcile.\n' "$RED" "$fails" "$NC"
  exit 1
fi
printf '%sverify: OK%s — all overlay checks passed.\n' "$GREEN" "$NC"
