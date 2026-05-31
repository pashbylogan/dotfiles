# Shared terminal palette for the repo's shell tooling — sourced by install and
# .github/scripts/verify.sh so the ANSI codes can't drift between them. Colors go
# empty when stdout isn't a TTY, so piped/CI output stays plain.
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
