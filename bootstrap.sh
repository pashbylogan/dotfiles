#!/usr/bin/env sh

set -eu

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/pashbyl/dotfiles.git}"
REPO_REF="${DOTFILES_REPO_REF:-master}"
REPO_DIR="${DOTFILES_REPO_DIR:-$HOME/projects/dotfiles}"
PROFILE="${DOTFILES_PROFILE:-auto}"

log() {
  printf '%s\n' "$*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

need_sudo() {
  [ "$(id -u)" -ne 0 ]
}

run_root() {
  if need_sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

detect_os() {
  uname -s
}

install_homebrew() {
  if ! have brew; then
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

install_linux_prereqs() {
  if have apt-get; then
    run_root apt-get update
    run_root apt-get install -y git curl stow age zsh python3 python3-venv python3-pip pipx
    python3 -m pipx ensurepath || true
    if ! have ansible-playbook; then
      run_root apt-get install -y ansible || run_root python3 -m pip install ansible
    fi
    return
  fi

  if have dnf; then
    run_root dnf install -y git curl stow age zsh python3 python3-pip ansible
    return
  fi

  if have pacman; then
    run_root pacman -Sy --noconfirm git curl stow age zsh python python-pip ansible
    return
  fi

  if have zypper; then
    run_root zypper --non-interactive install git curl stow age zsh python3 python3-pip ansible
    return
  fi

  log "Unsupported Linux package manager. Install git, stow, age, python3, and ansible manually."
  exit 1
}

install_macos_prereqs() {
  install_homebrew
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  brew install git stow age ansible
}

clone_or_update_repo() {
  mkdir -p "$(dirname "$REPO_DIR")"

  if [ -d "$REPO_DIR/.git" ]; then
    log "Updating existing dotfiles repo"
    git -C "$REPO_DIR" fetch --all --prune
    git -C "$REPO_DIR" checkout "$REPO_REF"
    git -C "$REPO_DIR" pull --ff-only origin "$REPO_REF"
  else
    log "Cloning dotfiles repo"
    git clone --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"
  fi
}

main() {
  os="$(detect_os)"
  case "$os" in
    Linux)
      install_linux_prereqs
      ;;
    Darwin)
      install_macos_prereqs
      ;;
    *)
      log "Unsupported OS: $os"
      exit 1
      ;;
  esac

  clone_or_update_repo

  log "Applying dotfiles"
  DOTFILES_PROFILE="$PROFILE" "$REPO_DIR/scripts/apply"
}

main "$@"
