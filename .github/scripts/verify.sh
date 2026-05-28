#!/usr/bin/env bash
# Read-only live-machine check; failures should be reconcilable with ./install.
# [D-CI][D-IDEMPOTENT][D-DELTA-STORAGE][F-HYPR-SEAM]

set -u

# ── output helpers ───────────────────────────────────────────────────────────
if [ -t 1 ]; then
  GREEN=$'\033[32m'
  RED=$'\033[31m'
  DIM=$'\033[2m'
  NC=$'\033[0m'
else
  GREEN=
  RED=
  DIM=
  NC=
fi

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

REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"

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
  local file="$1" marker="$2"
  if [ -f "$file" ] && grep -qxF -- "$marker" "$file"; then
    pass "$(pretty "$file") managed block present"
  else
    miss "$(pretty "$file") managed block missing — re-run ./install"
  fi
}
check_block "$HOME/.bashrc" '# >>> dotfiles managed (shell) >>>'
check_block "$HOME/.config/hypr/hyprland.conf" '# >>> dotfiles managed (hypr) >>>'
check_block "$HOME/.config/nvim/lua/config/keymaps.lua" '-- >>> dotfiles managed (keymaps) >>>'
check_block "$HOME/.config/tmux/tmux.conf" '# >>> dotfiles managed (tmux) >>>'

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
check_link "$HOME/.ssh/config"
check_link "$HOME/.config/tmux/local.conf"

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

# ── summary ──────────────────────────────────────────────────────────────────
echo
if [ "$fails" -gt 0 ]; then
  printf '%sverify: %d check(s) failed%s — re-run ./install to reconcile.\n' "$RED" "$fails" "$NC"
  exit 1
fi
printf '%sverify: OK%s — all overlay checks passed.\n' "$GREEN" "$NC"
