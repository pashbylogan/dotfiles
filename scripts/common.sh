#!/usr/bin/env bash

set -euo pipefail

# ─── Colors & helpers ────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${CYAN}ℹ ${NC}%s\n" "$*"; }
success() { printf "${GREEN}✔ ${NC}%s\n" "$*"; }
warn()    { printf "${YELLOW}⚠ ${NC}%s\n" "$*"; }
error()   { printf "${RED}✖ ${NC}%s\n" "$*" >&2; }
step()    { printf "\n${BOLD}── %s ──${NC}\n" "$*"; }

die() { error "$@"; exit 1; }

# ─── Core utilities ──────────────────────────────────────────────────────────

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

_DOTFILES_OS="$(uname -s)"
detect_os() { echo "$_DOTFILES_OS"; }

default_profile() {
  case "$(detect_os)" in
    Darwin) echo "macos_cli" ;;
    *) echo "linux_desktop" ;;
  esac
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
  if have apt-get; then
    run_root apt-get update
    run_root apt-get install -y stow python3 python3-pip python3-venv pipx
    python3 -m pipx ensurepath || true
    if ! have ansible-playbook; then
      run_root apt-get install -y ansible || run_root python3 -m pip install ansible
    fi
    return
  fi

  if have dnf; then
    run_root dnf install -y stow python3 python3-pip ansible
    return
  fi

  if have pacman; then
    run_root pacman -Syu --noconfirm --needed stow python python-pip ansible
    return
  fi

  if have zypper; then
    run_root zypper --non-interactive install stow python3 python3-pip ansible
    return
  fi

  die "Unsupported Linux package manager. Install stow, python3, and ansible manually."
}

ensure_macos_prereqs() {
  if ! have brew; then
    die "Homebrew is required on macOS. Run bootstrap.sh or install Homebrew first."
  fi

  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  brew install stow ansible
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
    Darwin)
      ensure_macos_prereqs
      ;;
    *)
      die "Unsupported OS: $(detect_os)"
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

  ANSIBLE_CONFIG="$root/ansible/ansible.cfg" ansible-playbook \
    -i "$root/ansible/inventory/hosts.yml" \
    "$root/ansible/site.yml" \
    -e "dotfiles_repo_root=$root" \
    -e "dotfiles_mode=$mode" \
    -e "dotfiles_profile=$profile" \
    "$@"

  local rc=$?
  echo ""
  if [[ $rc -eq 0 ]]; then
    success "${BOLD}${mode^} complete.${NC}"
  else
    error "${BOLD}${mode^} failed${NC} (exit code $rc)"
  fi
  return $rc
}
