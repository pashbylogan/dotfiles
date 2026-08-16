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

if [ ! -d /usr/share/omarchy ]; then
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
check_block "$HOME/.bashrc" shell '#'
check_block "$HOME/.config/hypr/hyprland.lua" hypr '--'
check_block "$HOME/.config/nvim/lua/config/keymaps.lua" keymaps '--'
check_block "$HOME/.config/tmux/tmux.conf" tmux '#'

legacy_hypr_begin="$(managed_marker begin hypr '#')"
if grep -qxF -- "$legacy_hypr_begin" "$HOME/.config/hypr/hyprland.conf" 2>/dev/null ||
  grep -qxF -- 'source = ~/.config/dotfiles/hypr.conf' "$HOME/.config/hypr/hyprland.conf" 2>/dev/null; then
  miss "legacy Hyprland source seam remains — re-run ./install"
else
  pass "legacy Hyprland source seam absent"
fi
unset legacy_hypr_begin

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
check_link "$HOME/.config/uwsm/env.d/dotfiles.sh"
check_link "$HOME/.ssh/config"
check_link "$HOME/.config/tmux/local.conf"
check_link "$HOME/.claude/statusline-command.sh"
check_link "$HOME/.config/omarchy/plugins/pashbyl.workspaces/manifest.json"
check_link "$HOME/.config/omarchy/plugins/pashbyl.workspaces/Workspaces.qml"

for legacy_link in \
  "$HOME/.config/dotfiles/hypr.conf" \
  "$HOME/.config/elephant/websearch.toml" \
  "$HOME/.config/omarchy/hooks/theme-set.d/brave-origin-stable" \
  "$HOME/.config/omarchy/bar/scripts/memory-status"; do
  if [ -e "$legacy_link" ] || [ -L "$legacy_link" ]; then
    miss "retired repo path remains: $(pretty "$legacy_link")"
  else
    pass "retired repo path absent: $(pretty "$legacy_link")"
  fi
done
unset legacy_link

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
if grep -qF 'opacity = "0.86 override 0.78 override"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF 'o.bind("SUPER + SPACE", "Apps menu"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF 'o.bind("SUPER + H", "Focus on left window"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF '"SUPER + SHIFT + S"' "$HYPR_MODULE" 2>/dev/null &&
  grep -qF '"SUPER + ALT + SPACE"' "$HYPR_MODULE" 2>/dev/null; then
  pass "Hyprland opacity, representative binds, and conflict unbinds are present"
else
  miss "Hyprland personal behavior is incomplete — restore/re-stow the module"
fi
if have luac && luac -p "$HYPR_MODULE"; then
  pass "Hyprland personal Lua parses"
elif have luac; then
  miss "Hyprland personal Lua does not parse"
else
  skip "standalone Lua parse (luac unavailable)"
fi
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

  # hyprctl -j nests each option under a type-specific key. Read it with has()
  # rather than `//` because jq treats both false and 0 as falsy.
  hypr_option() {
    hyprctl -j getoption "$1" 2>/dev/null |
      jq -r --arg k "$2" 'if has($k) then .[$k] else empty end' 2>/dev/null
  }
  # int and bool differ only in which key holds the value, so they share a body.
  check_hypr_scalar() {
    local option="$1" expected="$2" actual
    actual="$(hypr_option "$option" "$3")"
    if [ "$actual" = "$expected" ]; then
      pass "Hyprland $option = $expected"
    else
      miss "Hyprland $option = ${actual:-<unreadable>}, expected $expected"
    fi
  }
  check_hypr_int() { check_hypr_scalar "$1" "$2" int; }
  check_hypr_bool() { check_hypr_scalar "$1" "$2" bool; }
  check_hypr_custom() {
    local option="$1" expected="$2" actual
    # Hyprland 0.56 reports CSS-like gaps under .css; older builds used
    # .custom. Accept either representation while requiring every edge to
    # match the desired scalar.
    actual="$(hyprctl -j getoption "$option" 2>/dev/null | jq -r '.css // .custom // empty' 2>/dev/null)"
    if [ -n "$actual" ] && awk -v want="$expected" '{ for (i = 1; i <= NF; i++) if ($i != want) exit 1 }' <<<"$actual"; then
      pass "Hyprland $option = $expected"
    else
      miss "Hyprland $option = ${actual:-<unreadable>}, expected $expected"
    fi
  }
  check_hypr_float() {
    local option="$1" expected="$2" actual
    actual="$(hypr_option "$option" float)"
    if [ -n "$actual" ] && awk -v actual="$actual" -v expected="$expected" 'BEGIN { d = actual - expected; if (d < 0) d = -d; exit(d > 0.0001) }'; then
      pass "Hyprland $option = $expected"
    else
      miss "Hyprland $option = ${actual:-<unreadable>}, expected $expected"
    fi
  }
  # These are deliberate appearance deltas, not inherited defaults. [D-LOOKNFEEL]
  check_hypr_custom general:gaps_in 2
  check_hypr_custom general:gaps_out 4
  check_hypr_int general:border_size 2
  check_hypr_int decoration:rounding 8
  check_hypr_bool decoration:blur:enabled true
  check_hypr_int decoration:blur:size 8
  check_hypr_int decoration:blur:passes 2
  check_hypr_float decoration:blur:brightness 0.72
  check_hypr_float decoration:blur:contrast 0.75
  check_hypr_bool decoration:shadow:enabled true
  check_hypr_bool misc:focus_on_activate false
else
  skip "live Hyprland values (session unavailable)"
fi

# Quickshell uses an official plugin seam; shell.json remains mutable and must
# already be a fixed point under the repo delta. [D-QUICKSHELL-DELTAS]
SHELL_JSON="$HOME/.config/omarchy/shell.json"
if ! have omarchy-shell-config; then
  miss "omarchy-shell-config missing — Quattro shell helpers are unavailable"
elif [ ! -f "$SHELL_JSON" ]; then
  miss "$(pretty "$SHELL_JSON") missing — re-run ./install"
else
  # shellcheck source=/usr/bin/omarchy-shell-config disable=SC1090,SC1091
  . "$(command -v omarchy-shell-config)"
  shell_program="$NORMALIZE | $(<"$REPO/omarchy/shell.jq")"
  shell_expected="$(jq -S -e "$shell_program" "$SHELL_JSON" 2>/dev/null || true)"
  shell_actual="$(jq -S -e . "$SHELL_JSON" 2>/dev/null || true)"
  if [ -n "$shell_expected" ] && [ "$shell_expected" = "$shell_actual" ]; then
    pass "Quickshell layout delta fully applied"
  else
    miss "Quickshell layout drifted — re-run ./install"
  fi
  # The retired RAM widget must be gone, not merely unplaced. [D-QUICKSHELL-DELTAS]
  if jq -e '
    [.bar.layout.left[], .bar.layout.center[], .bar.layout.right[]] as $all
    | (($all | map(select(.id == "pashbyl.workspaces")) | length) == 1)
      and (($all | map(select(.id == "omarchy.workspaces")) | length) == 0)
      and (($all | map(select(.id == "dotfiles.memory")) | length) == 0)
  ' "$SHELL_JSON" >/dev/null 2>&1; then
    pass "workspace bar module placed, retired memory module absent"
  else
    miss "workspace/memory bar module placement is wrong"
  fi
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
if [ -L "$HOME/.config/omarchy/shell.toml" ]; then
  miss "Quickshell shell.toml is a symlink; keep mutable settings unstowed"
elif grep -qxF 'active = "#a55555"' "$HOME/.config/omarchy/shell.toml" 2>/dev/null; then
  pass "Quickshell urgent/active color override is exact"
else
  miss "Quickshell urgent/active color override drifted"
fi
if have omarchy-shell && omarchy-shell shell ping >/dev/null 2>&1; then
  pass "Quickshell IPC responds"
else
  skip "Quickshell IPC (shell not running in this session)"
fi
unset SHELL_JSON shell_program shell_expected shell_actual

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
for stale_foot_launcher in foot.desktop foot-server.desktop footclient.desktop; do
  if [ -e "$HOME/.local/share/applications/$stale_foot_launcher" ]; then
    miss "stale Foot launcher remains: $stale_foot_launcher"
  fi
done
unset stale_foot_launcher
unset mime_type

# Quattro owns agent installation and updates through mise wrappers; the repo
# owns only mutable user configuration. [D-CLAUDE-CONFIG][D-OPENCODE-LSP]
for legacy_agent_pkg in opencode claude-code; do
  if pkg_installed "$legacy_agent_pkg"; then
    miss "legacy $legacy_agent_pkg package installed; Quattro mise owns agents"
  else
    pass "legacy $legacy_agent_pkg package absent"
  fi
done
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
unset legacy_agent_pkg agent

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
check_jq_fixed_point "Claude" "$HOME/.claude/settings.json" "$REPO/claude/settings.jq"
check_jq_fixed_point "OpenCode" "$HOME/.config/opencode/opencode.json" "$REPO/opencode/settings.jq"

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
if [ -f "$HOME/.config/uwsm/env.d/99-omarchy-upgrade-env" ]; then
  miss "99-omarchy-upgrade-env remains — audit precedence and remove it"
else
  pass "temporary UWSM migration fragment absent"
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
elif grep -qxF 'right_format = "${custom.venv}"' "$STARSHIP_TOML"; then
  check_block "$STARSHIP_TOML" starship-venv '#'
  pass "starship right_format references the venv module"
  # A half-applied migration leaves both references and renders the venv twice.
  if grep -qF '${custom.venv}$character' "$STARSHIP_TOML"; then
    miss "legacy inline \${custom.venv} splice remains — re-run ./install"
  else
    pass "legacy inline venv splice absent"
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

discord_webapp="$HOME/.local/share/applications/Discord.desktop"
if [ -f "$discord_webapp" ] && grep -qxF 'Exec=omarchy-launch-webapp https://discord.com/channels/@me' "$discord_webapp"; then
  pass "Discord uses Quattro's stock web app"
else
  miss "Discord Quattro web app missing or drifted"
fi
unset discord_webapp

for retained_pkg in omacalc obsidian; do
  if pkg_installed "$retained_pkg"; then
    pass "retained Quattro package present: $retained_pkg"
  else
    miss "retained Quattro package missing: $retained_pkg"
  fi
done
unset retained_pkg

for retired_unit in elephant.service app-walker@autostart.service; do
  if systemctl --user is-enabled "$retired_unit" >/dev/null 2>&1; then
    miss "retired unit still enabled: $retired_unit"
  else
    pass "retired unit disabled: $retired_unit"
  fi
done
for retired_pkg in waybar walker-bin omarchy-walker elephant elephant-calc elephant-desktopapplications elephant-files elephant-symbols; do
  if pkg_installed "$retired_pkg"; then
    miss "retired package still installed: $retired_pkg"
  fi
done
unset retired_unit retired_pkg

legacy_omarchy="$(readlink -f "$HOME/.local/share/omarchy" 2>/dev/null || true)"
cleanup_hook="$HOME/.config/omarchy/hooks/post-boot.d/cleanup-upgrade-to-quattro-live-shim"
if [ "$legacy_omarchy" = /usr/share/omarchy ] && [ ! -e "$cleanup_hook" ]; then
  pass "Quattro live shim cleanup completed"
else
  miss "Quattro live shim cleanup incomplete (target=${legacy_omarchy:-missing})"
fi
unset legacy_omarchy cleanup_hook

echo
if [ "$fails" -gt 0 ]; then
  printf '%sverify: %d check(s) failed%s — re-run ./install to reconcile.\n' "$RED" "$fails" "$NC"
  exit 1
fi
printf '%sverify: OK%s — all Quattro overlay checks passed.\n' "$GREEN" "$NC"
