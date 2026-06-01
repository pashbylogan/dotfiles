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

# Begin/end sentinel for a managed block. install writes these and verify.sh
# greps for them (whole-line), so the `>>> dotfiles managed (NAME) >>>` contract
# lives here once. $1=begin|end  $2=name  $3=comment-open  $4=comment-close(opt).
managed_marker() {
  local s='>>>'
  [ "$1" = end ] && s='<<<'
  printf '%s %s dotfiles managed (%s) %s%s' "$3" "$s" "$2" "$s" "${4:-}"
}
