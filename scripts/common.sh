#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '%s\n' "$*"
}

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

detect_os() {
  uname -s
}

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

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
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

have() {
  command -v "$1" >/dev/null 2>&1
}

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
    run_root pacman -Sy --noconfirm stow python python-pip ansible
    return
  fi

  if have zypper; then
    run_root zypper --non-interactive install stow python3 python3-pip ansible
    return
  fi

  log "Unsupported Linux package manager. Install stow, python3, and ansible manually."
  exit 1
}

ensure_macos_prereqs() {
  if ! have brew; then
    log "Homebrew is required on macOS. Run bootstrap.sh or install Homebrew first."
    exit 1
  fi

  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  brew install stow ansible
}

ensure_prereqs() {
  if have ansible-playbook && have stow; then
    return
  fi

  log "Installing missing prerequisites"
  case "$(detect_os)" in
    Linux)
      ensure_linux_prereqs
      ;;
    Darwin)
      ensure_macos_prereqs
      ;;
    *)
      log "Unsupported OS: $(detect_os)"
      exit 1
      ;;
  esac
}

run_playbook() {
  local mode="$1"
  shift || true

  local root
  root="$(repo_root)"

  ensure_prereqs
  require_cmd ansible-playbook

  ANSIBLE_CONFIG="$root/ansible/ansible.cfg" ansible-playbook \
    -i "$root/ansible/inventory/hosts.yml" \
    "$root/ansible/site.yml" \
    -e "dotfiles_repo_root=$root" \
    -e "dotfiles_mode=$mode" \
    -e "dotfiles_profile=$(resolved_profile)" \
    "$@"
}
