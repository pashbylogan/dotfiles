# Shared definitions for the repo's shell tooling — sourced by install and
# .github/scripts/verify.sh so they can't drift between the writer and the
# checker: the TTY-gated ANSI palette, and the managed-block marker contract.
# Colors go empty when stdout isn't a TTY, so piped/CI output stays plain.
# shellcheck shell=bash
# Vars are consumed by the sourcing scripts, not here.
# shellcheck disable=SC2034

if [ -t 1 ]; then
  BOLD=$'\033[1m'
  CYAN=$'\033[0;36m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  RED=$'\033[0;31m'
  DIM=$'\033[2m'
  NC=$'\033[0m'
else
  BOLD='' CYAN='' GREEN='' YELLOW='' RED='' DIM='' NC=''
fi

have() { command -v "$1" >/dev/null 2>&1; }

# Declarative manifests accept comments, whitespace, blank lines, and CRLF.
# Keep install and verification on one parser so desired state cannot drift.
parse_list_file() {
  tr -d '\r' <"$1" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' || true
}

# Stock Quattro web apps this overlay keeps. install restores them through the
# native application refresh and verify.sh asserts them against Quattro's
# packaged copies, from one list so desired state cannot drift. [D-WEBAPP]
RETAINED_WEBAPPS=(Discord Zoom)

# Alternate-terminal launchers Quattro's application refresh recreates from its
# packaged set, keyed by the pacman package that owns each. A launcher is stale
# only once its package is gone, so install removes and verify.sh asserts under
# the same condition, from one list. [D-TERM-GHOSTTY]
declare -A STALE_TERMINAL_LAUNCHERS=(
  [alacritty]=Alacritty.desktop
  [foot]=foot.desktop
)

# xdg-settings asserts only the primary handler, so install sets and verify.sh
# checks these associations explicitly — from one list, so they cannot drift.
# [D-BROWSER-DEFAULT]
BRAVE_MIME_TYPES=(
  x-scheme-handler/http
  x-scheme-handler/https
  x-scheme-handler/chrome
  text/html
  application/x-extension-htm
  application/x-extension-html
  application/x-extension-shtml
  application/xhtml+xml
  application/x-extension-xhtml
  application/x-extension-xht
)

# Omarchy's install root, defaulted the way its own env-bootstrap defaults it,
# so install and verify.sh resolve packaged files identically.
: "${OMARCHY_PATH:=/usr/share/omarchy}"

# Claude Code's config root, resolved the way omarchy-theme-set-claude resolves
# it — hardcoding $HOME/.claude would make install warn and verify fail on a
# machine where CLAUDE_CONFIG_DIR points elsewhere. [D-CLAUDE-CONFIG]
CLAUDE_CONFIG_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CLAUDE_SETTINGS_FILE="$CLAUDE_CONFIG_HOME/settings.json"
CLAUDE_THEME_FILE="$CLAUDE_CONFIG_HOME/themes/omarchy.json"

# Begin/end sentinel for a managed block. install writes these and verify.sh
# greps for them (whole-line), so the `>>> dotfiles managed (NAME) >>>` contract
# lives here once. $1=begin|end  $2=name  $3=comment-open  $4=comment-close(opt).
managed_marker() {
  local s='>>>'
  [ "$1" = end ] && s='<<<'
  printf '%s %s dotfiles managed (%s) %s%s' "$3" "$s" "$2" "$s" "${4:-}"
}
