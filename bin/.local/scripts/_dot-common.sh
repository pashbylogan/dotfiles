#!/usr/bin/env bash

set -euo pipefail

# ─── Colors & helpers ────────────────────────────────────────────────────────

# Use ANSI-C quoting so the variables contain the actual ESC byte (0x1B)
# rather than the four-character string `\033`. Without this, embedding
# `${BOLD}` inside a `%s` argument prints the escape literally because
# `printf` only interprets `\033` in the format string.
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

info()    { printf "${CYAN}ℹ ${NC}%s\n" "$*"; }
success() { printf "${GREEN}✔ ${NC}%s\n" "$*"; }
warn()    { printf "${YELLOW}⚠ ${NC}%s\n" "$*"; }
error()   { printf "${RED}✖ ${NC}%s\n" "$*" >&2; }
step()    { printf "\n${BOLD}── %s ──${NC}\n" "$*"; }

die() { error "$@"; exit 1; }

# ─── Core utilities ──────────────────────────────────────────────────────────

repo_root() {
  git -C "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" rev-parse --show-toplevel
}

_DOTFILES_OS="$(uname -s)"
detect_os() { echo "$_DOTFILES_OS"; }

default_profile() {
  echo "linux_desktop"
}

resolved_profile() {
  local requested="${DOTFILES_PROFILE:-auto}"
  if [[ "$requested" == "auto" ]]; then
    default_profile
  else
    echo "$requested"
  fi
}

have() {
  command -v "$1" >/dev/null 2>&1
}

need_sudo() {
  [[ "$(id -u)" -ne 0 ]]
}

run_root() {
  if need_sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

# ─── Prerequisite installation ───────────────────────────────────────────────

ensure_linux_prereqs() {
  if have dnf; then
    run_root dnf install -y stow python3 python3-pip \
      ansible-core ansible-collection-community-general
    return
  fi

  die "Unsupported Linux package manager. This repo supports Fedora Linux (dnf/dnf5) only."
}

ensure_prereqs() {
  if have ansible-playbook && have stow; then
    return
  fi

  step "Installing missing prerequisites"
  case "$(detect_os)" in
    Linux)
      ensure_linux_prereqs
      ;;
    *)
      die "Unsupported OS: $(detect_os). This repo supports Fedora Linux only."
      ;;
  esac
  success "Prerequisites installed"
}

# ─── Playbook runner ─────────────────────────────────────────────────────────

run_playbook() {
  local mode="$1"
  shift || true

  local root
  root="$(repo_root)"
  local profile
  profile="$(resolved_profile)"

  step "Dotfiles ${mode} — profile: ${BOLD}${profile}${NC}"
  info "Repo root: ${root}"

  ensure_prereqs

  if [[ "$mode" == "check" ]]; then
    info "Running in ${BOLD}check mode${NC} (no changes will be made)"
  fi

  step "Running Ansible playbook"

  local -a hostname_args=()
  if [[ -n "${DOTFILES_HOSTNAME:-}" ]]; then
    hostname_args=(-e "dotfiles_hostname=${DOTFILES_HOSTNAME}")
  fi

  local rc=0
  ANSIBLE_CONFIG="$root/ansible/ansible.cfg" ansible-playbook \
    -i "$root/ansible/inventory/hosts.yml" \
    "$root/ansible/site.yml" \
    -e "dotfiles_repo_root=$root" \
    -e "dotfiles_mode=$mode" \
    -e "dotfiles_profile=$profile" \
    "${hostname_args[@]}" \
    "$@" || rc=$?

  echo ""
  if [[ $rc -eq 0 ]]; then
    success "${BOLD}${mode^} complete.${NC}"
  else
    error "${BOLD}${mode^} failed${NC} (exit code $rc)"
  fi
  return $rc
}
