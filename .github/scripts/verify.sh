#!/usr/bin/env bash
# Live-machine overlay health check, invoked by `make verify` (also from
# `make update`'s tail). Read-only — no sudo, no installs. Exit 0 = pass,
# exit 1 = at least one check failed (typically: re-run ./install to reconcile).
# [D-CI][D-IDEMPOTENT][D-DELTA-STORAGE][F-HYPR-SEAM]

set -u

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
# Cosmetic: print absolute home paths as ~/... in output. Anchored to a path
# boundary so /home/userN-backup/x doesn't get mis-shortened to ~-backup/x.
pretty() {
  # The "~" in the printf output is a literal character for display, not a
  # tilde-expansion target — disable shellcheck's well-meaning warning.
  # shellcheck disable=SC2088
  case "$1" in
    "$HOME"/*) printf '%s' "~/${1#"$HOME"/}" ;;
    "$HOME") printf '%s' "~" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Repo root (script lives at .github/scripts/verify.sh).
REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"

# ── Hyprland config errors (only meaningful while Hyprland is running) ──────
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

# ── Managed blocks present in each integration target ──────────────────────
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

# ── Stow symlinks (sample of repo-managed files; must resolve into the repo) ─
check_link() {
  local link="$1" resolved
  if [ ! -L "$link" ]; then
    miss "$(pretty "$link") is not a symlink (expected stow link into the repo)"
    return
  fi
  resolved="$(readlink -f "$link" 2>/dev/null || true)"
  # `readlink -f` returns the canonical *would-be* path even when the target
  # doesn't exist — so a dangling symlink pointing into the repo would otherwise
  # report green. `-e` follows the link and tests for target existence.
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

# ── Dev-env tools on PATH and NOT owned by pacman ──────────────────────────
# (We don't pin paths — omarchy's dev-env lands these wherever the underlying
# tool's default is, which can shift; the contract is "dev-env owns this tool,
# not pacman.") One failure max per tool — pacman-ownership shadows the PATH
# question, since `./install` will drop the pacman copy and reinstall.
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

# ── XDG user dirs (per ./install) ───────────────────────────────────────────
# We match the literal $HOME text since that's what xdg-user-dirs-update writes
# for the spec keys. For values ending in '/' (the "collapsed to $HOME" form),
# we also accept the slash-less variant — xdg-user-dirs versions differ on
# whether they emit a trailing slash when the target equals $HOME exactly.
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

# ── Summary ─────────────────────────────────────────────────────────────────
echo
if [ "$fails" -gt 0 ]; then
  printf '%sverify: %d check(s) failed%s — re-run ./install to reconcile.\n' "$RED" "$fails" "$NC"
  exit 1
fi
printf '%sverify: OK%s — all overlay checks passed.\n' "$GREEN" "$NC"
