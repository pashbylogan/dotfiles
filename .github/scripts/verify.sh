#!/usr/bin/env bash
# Read-only live-machine check; failures should be reconcilable with ./install.
# [D-CI][D-IDEMPOTENT][D-DELTA-STORAGE][F-HYPR-SEAM]

set -u

REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
# shellcheck source=lib/style.sh
. "$REPO/lib/style.sh"

# This script tests ~39 package names; one `pacman -Qq` spawn per name costs
# ~300ms of a ~790ms run, so snapshot the installed set once instead. Safe only
# because verify is read-only — install mutates packages between its own checks
# and must keep querying pacman directly.
declare -A INSTALLED_PKGS=()
while IFS= read -r installed_pkg; do
  INSTALLED_PKGS["$installed_pkg"]=1
done < <(pacman -Qq 2>/dev/null)
unset installed_pkg
pkg_installed() { [ -n "${INSTALLED_PKGS[$1]:-}" ]; }

fails=0
pass() { printf '  %s✓%s %s\n' "$GREEN" "$NC" "$1"; }
miss() {
  printf '  %s✗%s %s\n' "$RED" "$NC" "$1"
  fails=$((fails + 1))
}
skip() { printf '  %s- skipped: %s%s\n' "$DIM" "$1" "$NC"; }
pretty() {
  # The printed tilde is display text, not a shell expansion target.
  # shellcheck disable=SC2088
  case "$1" in
    "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
    "$HOME") printf '~' ;;
    *) printf '%s' "$1" ;;
  esac
}

if [ ! -d "$OMARCHY_PATH" ]; then
  miss "Omarchy Quattro layout absent — upgrade before validating this branch"
  printf '\n%sverify: %d check(s) failed%s\n' "$RED" "$fails" "$NC"
  exit 1
fi
pass "Omarchy Quattro package layout present"

check_block() {
  local file="$1" marker
  marker="$(managed_marker begin "$2" "$3" "${4:-}")"
  if [ -f "$file" ] && grep -qxF -- "$marker" "$file"; then
    pass "$(pretty "$file") managed block present"
  else
    miss "$(pretty "$file") managed block missing — re-run ./install"
  fi
}

# Mutable upstream files keep only small, re-assertable seams. [D-DELTA-STORAGE]
# The nvim keymaps block is asserted below, under the seed guard.
check_block "$HOME/.bashrc" shell '#'
check_block "$HOME/.config/hypr/hyprland.lua" hypr '--'
check_block "$HOME/.config/tmux/tmux.conf" tmux '#'

check_link() {
  local link="$1" resolved
  if [ ! -L "$link" ]; then
    miss "$(pretty "$link") is not a Stow symlink"
    return
  fi
  resolved="$(readlink -f "$link" 2>/dev/null || true)"
  if [ ! -e "$link" ]; then
    miss "$(pretty "$link") is dangling -> $resolved"
  elif [[ $resolved == "$REPO"/* ]]; then
    pass "$(pretty "$link") -> repo"
  else
    miss "$(pretty "$link") resolves outside the repo ($resolved)"
  fi
}

check_link "$HOME/.config/dotfiles/shell.sh"
check_link "$HOME/.config/hypr/dotfiles.lua"
check_link "$HOME/.config/dotfiles/nvim.lua"
check_link "$HOME/.config/dotfiles/nvim-plugins.lua"
check_link "$HOME/.config/uwsm/env.d/dotfiles.sh"
check_link "$HOME/.ssh/config"
check_link "$HOME/.config/tmux/local.conf"
check_link "$HOME/.claude/statusline-command.sh"
check_link "$HOME/.config/omarchy/plugins/pashbyl.workspaces/manifest.json"
check_link "$HOME/.config/omarchy/plugins/pashbyl.workspaces/Workspaces.qml"

# The hypr.* namespace is purged by Quattro on reload; dotfiles.* is not.
# Verify both the module name and the optional-module binding. [F-HYPR-SEAM]
HYPR_MAIN="$HOME/.config/hypr/hyprland.lua"
if grep -qF 'require("hypr.dotfiles")' "$HYPR_MAIN" 2>/dev/null &&
  grep -qF 'local require_optional = require("default.hypr.require_optional")' "$HYPR_MAIN" 2>/dev/null &&
  grep -qF 'require_optional.module("hypr.dotfiles_local")' "$HYPR_MAIN" 2>/dev/null; then
  pass "Hyprland reloadable overlay seam is intact"
else
  miss "Hyprland overlay seam drifted — re-run ./install"
fi
unset HYPR_MAIN

HYPR_MODULE="$HOME/.config/hypr/dotfiles.lua"
if grep -qF 'opacity = "0.86 0.78"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF 'o.bind("SUPER + SPACE", "Apps menu"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF 'o.bind("SUPER + H", "Focus on left window"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF '"SUPER + SHIFT + S"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF '"SUPER + ALT + SPACE"' "$HYPR_MODULE" 2>/dev/null; then
  pass "Hyprland opacity, representative binds, and conflict unbinds are present"
else
  miss "Hyprland personal behavior is incomplete — restore/re-stow the module"
fi
# Typo-catcher only: luac is Lua 5.5 while nvim runs LuaJIT (5.1), so this
# parses syntax but cannot prove LuaJIT compatibility. [D-NVIM-KEYMAPS]
check_lua_parse() {
  if ! have luac; then
    skip "$(pretty "$1") parse (luac unavailable)"
  elif luac -p "$1"; then
    pass "$(pretty "$1") parses"
  else
    miss "$(pretty "$1") does not parse"
  fi
}
check_lua_parse "$HYPR_MODULE"
check_lua_parse "$HOME/.config/dotfiles/nvim.lua"
check_lua_parse "$HOME/.config/dotfiles/nvim-plugins.lua"
unset HYPR_MODULE

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && have hyprctl; then
  errs="$(hyprctl configerrors 2>&1 || true)"
  if printf '%s' "$errs" | grep -qiF "couldn't connect"; then
    skip "hyprctl (stale instance signature)"
  elif [ -z "${errs//[[:space:]]/}" ] || printf '%s' "$errs" | grep -qiF 'no error'; then
    pass "hyprctl: no config errors"
  else
    miss "hyprctl: config errors — run 'hyprctl configerrors'"
  fi

  # Every value the overlay actually sets. border_size is included because the
  # overlay deliberately restates it to beat window-no-gaps; values we merely
  # inherit are not asserted, since ./install could not reconcile them.
  # Ordered "option kind expected" triples — option names contain colons but no
  # spaces, so a plain read splits them. [D-LOOKNFEEL]
  hypr_checks=(
    "general:gaps_in edges 2"
    "general:gaps_out edges 4"
    "general:border_size int 2"
    "decoration:rounding int 8"
    "decoration:blur:enabled bool true"
    "decoration:blur:passes int 2"
    "decoration:blur:brightness float 0.72"
    "decoration:blur:contrast float 0.75"
    "decoration:shadow:enabled bool true"
    "misc:focus_on_activate bool false"
  )
  # One batched query instead of an hyprctl+jq pair per option: 11 options cost
  # ~3ms batched against ~32ms serially, on a script `make update` runs too.
  # Read each value with has() rather than `//` because jq treats false and 0 as
  # falsy; gaps arrive under .css on 0.56 and .custom on older builds.
  declare -A hypr_actual=()
  while IFS=$'\t' read -r hypr_key hypr_val; do
    hypr_actual["$hypr_key"]=$hypr_val
  done < <(
    hyprctl -j --batch "$(printf 'getoption %s;' "${hypr_checks[@]%% *}" | sed 's/;$//')" 2>/dev/null |
      jq -rs '.[] | [.option, (
          if has("css") then .css
          elif has("custom") then .custom
          elif has("int") then (.int | tostring)
          elif has("float") then (.float | tostring)
          elif has("bool") then (.bool | tostring)
          else "" end)] | @tsv' 2>/dev/null
  )
  for hypr_spec in "${hypr_checks[@]}"; do
    read -r hypr_option hypr_kind hypr_want <<<"$hypr_spec"
    hypr_got="${hypr_actual[$hypr_option]:-}"
    hypr_ok=0
    if [ -n "$hypr_got" ]; then
      case "$hypr_kind" in
        # Every edge of a CSS-style gap value must equal the desired scalar.
        edges)
          awk -v want="$hypr_want" \
            '{ for (i = 1; i <= NF; i++) if ($i != want) exit 1 }' <<<"$hypr_got" && hypr_ok=1
          ;;
        float)
          awk -v a="$hypr_got" -v b="$hypr_want" \
            'BEGIN { d = a - b; if (d < 0) d = -d; exit(d > 0.0001) }' && hypr_ok=1
          ;;
        *) [ "$hypr_got" = "$hypr_want" ] && hypr_ok=1 ;;
      esac
    fi
    if [ "$hypr_ok" -eq 1 ]; then
      pass "Hyprland $hypr_option = $hypr_want"
    else
      miss "Hyprland $hypr_option = ${hypr_got:-<unreadable>}, expected $hypr_want"
    fi
  done
  unset hypr_checks hypr_actual hypr_spec hypr_option hypr_kind hypr_want hypr_got hypr_key hypr_val hypr_ok
else
  skip "live Hyprland values (session unavailable)"
fi

# The bar layout is converged by Quattro's `omarchy bar` CLI, which owns the
# mechanism, so assert only the desired end state here. [D-QUICKSHELL-DELTAS]
SHELL_JSON="$HOME/.config/omarchy/shell.json"
if [ ! -f "$SHELL_JSON" ]; then
  miss "$(pretty "$SHELL_JSON") missing — re-run ./install"
elif jq -e '
  [.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]] as $all
  | (.bar.layout.left | map(.id) | index("omarchy.menu")) as $menu
  | (.bar.layout.left | map(.id) | index("pashbyl.workspaces")) as $ws
  | (($all | map(select(.id == "pashbyl.workspaces")) | length) == 1)
    and (($all | map(select(.id == "omarchy.workspaces")) | length) == 0)
    and ($ws != null)
    and ($menu == null or $ws == ($menu + 1))
' "$SHELL_JSON" >/dev/null 2>&1; then
  pass "workspace module placed after the menu; stock module absent"
else
  miss "Quickshell bar layout drifted — re-run ./install"
fi
if jq -e '
  .id == "pashbyl.workspaces"
  and .entryPoints.barWidget == "Workspaces.qml"
  and .omarchy.clonedFrom == "omarchy.workspaces"
' "$HOME/.config/omarchy/plugins/pashbyl.workspaces/manifest.json" >/dev/null 2>&1; then
  pass "workspace plugin manifest matches the supported clone shape"
else
  miss "workspace plugin manifest is invalid"
fi
if grep -qF 'root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus' \
  "$HOME/.config/omarchy/plugins/pashbyl.workspaces/Workspaces.qml" 2>/dev/null; then
  pass "workspace click uses Quattro Lua dispatch"
else
  miss "workspace click dispatch drifted from Quattro's supported form"
fi
if have omarchy-shell && omarchy-shell shell ping >/dev/null 2>&1; then
  pass "Quickshell IPC responds"
else
  skip "Quickshell IPC (shell not running in this session)"
fi
unset SHELL_JSON

# Official default flows own all browser/terminal integration. [D-BROWSER-DEFAULT][D-TERM-GHOSTTY]
if [ "$(omarchy default browser 2>/dev/null)" = brave-origin ]; then
  pass "default browser is Brave Origin"
else
  miss "default browser is not Brave Origin — re-run ./install"
fi
for mime_type in "${BRAVE_MIME_TYPES[@]}"; do
  if [ "$(xdg-mime query default "$mime_type" 2>/dev/null)" = brave-origin.desktop ]; then
    pass "$mime_type -> brave-origin.desktop"
  else
    miss "$mime_type is not associated with Brave Origin"
  fi
done
if [ "$(omarchy default terminal 2>/dev/null)" = ghostty ]; then
  pass "default terminal is Ghostty"
else
  miss "default terminal is not Ghostty — re-run ./install"
fi
# Guard on the package exactly as install does: while the terminal is installed
# its launcher is legitimate, and flagging it would report drift ./install
# cannot reconcile. [D-TERM-GHOSTTY]
for stale_pkg in "${!STALE_TERMINAL_LAUNCHERS[@]}"; do
  stale_file="${STALE_TERMINAL_LAUNCHERS[$stale_pkg]}"
  if pkg_installed "$stale_pkg"; then
    skip "stale $stale_file check ($stale_pkg still installed)"
  elif [ -e "$HOME/.local/share/applications/$stale_file" ]; then
    miss "stale terminal launcher remains: $stale_file — re-run ./install"
  else
    pass "stale terminal launcher absent: $stale_file"
  fi
done
unset stale_pkg stale_file mime_type

# Quattro owns agent installation and updates through mise wrappers; the repo
# owns only mutable user configuration. [D-CLAUDE-CONFIG][D-OPENCODE-LSP]
if have mise; then
  pass "mise is available for Quattro agent wrappers"
else
  miss "mise missing — Quattro agent wrappers cannot install/update"
fi
for agent in codex claude crush gemini copilot opencode pi omp grok; do
  if [ -x "$HOME/.local/bin/$agent" ] && grep -qF 'mise use -g' "$HOME/.local/bin/$agent"; then
    pass "$agent uses an Omarchy mise wrapper"
  else
    miss "$agent mise wrapper missing or drifted"
  fi
done
unset agent

check_jq_fixed_point() {
  local label="$1" target="$2" filter="$3" expected actual
  if [ ! -f "$target" ]; then
    miss "$(pretty "$target") missing — re-run ./install"
    return
  fi
  expected="$(jq -S -f "$filter" "$target" 2>/dev/null || true)"
  actual="$(jq -S . "$target" 2>/dev/null || true)"
  if [ -n "$expected" ] && [ "$expected" = "$actual" ]; then
    pass "$label overlay fully applied"
  else
    miss "$label overlay drifted — re-run ./install"
  fi
}
# OpenCode's global LSP delta remains tool-owned mutable state. [F-OPENCODE-LSP]
check_jq_fixed_point "Claude" "$CLAUDE_SETTINGS_FILE" "$REPO/claude/settings.jq"
check_jq_fixed_point "OpenCode" "$HOME/.config/opencode/opencode.json" "$REPO/opencode/settings.jq"

# settings.jq pins .theme to custom:omarchy, so the Quattro-generated theme file
# must exist or Claude Code resolves a dangling reference. [D-CLAUDE-CONFIG]
if [ -f "$CLAUDE_THEME_FILE" ]; then
  pass "Claude Code Omarchy theme present"
else
  miss "$(pretty "$CLAUDE_THEME_FILE") missing — .theme pins custom:omarchy"
fi

# These seams live inside the omarchy-nvim seed, which ./install cannot create
# pre-seed — hence skip, not miss. [D-NVIM-KEYMAPS][F-NVIM-OWNED]
if [ ! -d "$NVIM_PLUGINS_DIR" ]; then
  skip "nvim seams (~/.config/nvim not seeded — run omarchy-nvim-setup, then ./install)"
else
  check_block "$HOME/.config/nvim/lua/config/keymaps.lua" keymaps '--'
  # install writes the loader in one shot, so the fragment path it dofiles is
  # the whole contract — a second grep would assert the same fact twice.
  if grep -qF 'dotfiles/nvim-plugins.lua' "$NVIM_PLUGIN_LOADER" 2>/dev/null; then
    pass "$(pretty "$NVIM_PLUGIN_LOADER") loader present"
  else
    miss "$(pretty "$NVIM_PLUGIN_LOADER") loader missing or drifted — re-run ./install"
  fi
  check_jq_fixed_point "LazyVim extras" "$HOME/.config/nvim/lazyvim.json" "$REPO/nvim/lazyvim.jq"
fi

# SSH silently ignores over-permissive configuration. [F-SSH-AGENT]
check_mode() {
  local path="$1" expected="$2" actual
  if [ ! -e "$path" ]; then
    miss "$(pretty "$path") missing"
    return
  fi
  # Stow-managed config paths are symlinks; SSH evaluates the target mode.
  actual="$(stat -Lc '%a' "$path" 2>/dev/null || true)"
  if [ "$actual" = "$expected" ]; then
    pass "$(pretty "$path") mode $expected"
  else
    miss "$(pretty "$path") mode ${actual:-?}, expected $expected"
  fi
}
check_mode "$HOME/.ssh" 700
check_mode "$HOME/.ssh/config" 600
[ ! -e "$HOME/.ssh/config.local" ] || check_mode "$HOME/.ssh/config.local" 600
if state="$(systemctl --user is-enabled ssh-agent.socket 2>/dev/null)"; then
  pass "ssh-agent.socket $state"
elif [ -z "${state:-}" ]; then
  skip "ssh-agent.socket (systemd user manager not reachable)"
else
  miss "ssh-agent.socket $state"
fi
check_tool() {
  local tool="$1" current
  if pkg_installed "$tool"; then
    miss "$tool is pacman-owned; expected Omarchy dev-env ownership"
    return
  fi
  current="$(command -v "$tool" 2>/dev/null || true)"
  if [ -n "$current" ]; then
    pass "$tool on PATH ($(pretty "$current"))"
  else
    miss "$tool not on PATH"
  fi
}
check_tool uv
check_tool go

check_xdg() {
  local key="$1" expected="$2" file="$HOME/.config/user-dirs.dirs" alt=""
  [[ $expected == */ ]] && alt="${expected%/}"
  if [ -f "$file" ] && {
    grep -qxF -- "$key=\"$expected\"" "$file" ||
      { [ -n "$alt" ] && grep -qxF -- "$key=\"$alt\"" "$file"; }
  }; then
    pass "XDG $key = $expected"
  else
    miss "XDG $key != $expected"
  fi
}
# shellcheck disable=SC2016
check_xdg XDG_DOCUMENTS_DIR '$HOME/'
# shellcheck disable=SC2016
check_xdg XDG_MUSIC_DIR '$HOME/'
# shellcheck disable=SC2016
check_xdg XDG_PROJECTS_DIR '$HOME/Projects'

# [D-STARSHIP-VENV]
STARSHIP_TOML="$HOME/.config/starship.toml"
# shellcheck disable=SC2016
if [ ! -f "$STARSHIP_TOML" ]; then
  skip "starship venv overlay ($(pretty "$STARSHIP_TOML") not present)"
elif grep -qF '$python$character' "$STARSHIP_TOML"; then
  check_block "$STARSHIP_TOML" starship-venv '#'
  pass "starship format references the venv module"
  # right_format is never rendered by starship's bash init unless ble.sh is
  # attached, so a reference parked there is invisible, not merely misplaced.
  if grep -q '^[[:space:]]*right_format[[:space:]]*=' "$STARSHIP_TOML"; then
    miss "starship right_format is set but bash renders it only under ble.sh"
  else
    pass "no unrenderable starship right_format"
  fi
else
  miss "starship venv reference missing"
fi
unset STARSHIP_TOML

# Every deny-list entry is desired absent state; pkg drop may refuse a real
# reverse dependency, which this makes visible rather than hiding. [D-PKG-REMOVE]
while IFS= read -r unwanted; do
  if pkg_installed "$unwanted"; then
    miss "unwanted package remains: $unwanted"
  fi
done < <(parse_list_file "$REPO/packages.remove.txt")
unset unwanted

# Quattro may recopy its stock web apps during an application refresh; surface
# that drift so running install re-applies the supported removals. [D-WEBAPP]
while IFS= read -r unwanted_webapp; do
  if [ -f "$HOME/.local/share/applications/$unwanted_webapp.desktop" ]; then
    miss "unwanted web app remains: $unwanted_webapp"
  fi
done < <(parse_list_file "$REPO/webapps.remove.txt")
unset unwanted_webapp

# Compare against Quattro's packaged copy rather than restating its Exec line,
# so an upstream URL change is not read as local drift. [D-WEBAPP]
mapfile -t RETAINED_WEBAPPS < <(retained_webapps)
for retained_webapp in "${RETAINED_WEBAPPS[@]}"; do
  retained_user="$HOME/.local/share/applications/$retained_webapp.desktop"
  retained_stock="$OMARCHY_PATH/applications/$retained_webapp.desktop"
  if [ ! -f "$retained_stock" ]; then
    skip "$retained_webapp web app (Quattro no longer packages it)"
  elif [ ! -f "$retained_user" ]; then
    miss "retained web app missing: $retained_webapp — re-run ./install"
  elif cmp -s "$retained_user" "$retained_stock"; then
    pass "$retained_webapp uses Quattro's stock web app"
  else
    miss "$retained_webapp launcher drifted from Quattro's packaged copy"
  fi
done
unset retained_webapp retained_user retained_stock

for retained_pkg in omacalc obsidian; do
  if pkg_installed "$retained_pkg"; then
    pass "retained Quattro package present: $retained_pkg"
  else
    miss "retained Quattro package missing: $retained_pkg"
  fi
done
unset retained_pkg

echo
if [ "$fails" -gt 0 ]; then
  printf '%sverify: %d check(s) failed%s — re-run ./install to reconcile.\n' "$RED" "$fails" "$NC"
  exit 1
fi
printf '%sverify: OK%s — all Quattro overlay checks passed.\n' "$GREEN" "$NC"
