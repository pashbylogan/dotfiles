#!/usr/bin/env sh

set -eu

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/pashbylogan/dotfiles.git}"
REPO_REF="${DOTFILES_REPO_REF:-master}"
REPO_DIR="${DOTFILES_REPO_DIR:-$HOME/projects/dotfiles}"
PROFILE="${DOTFILES_PROFILE:-auto}"

# ─── Colors & helpers ────────────────────────────────────────────────────────
# Self-contained — cannot source common.sh because the repo may not exist yet.

# Store the actual ESC byte so colors work when embedded in `%s` arguments,
# not just in printf format strings. Use POSIX sh syntax because this file is
# the remote `curl | sh` entrypoint.
RED="$(printf '\033[0;31m')"
GREEN="$(printf '\033[0;32m')"
YELLOW="$(printf '\033[1;33m')"
CYAN="$(printf '\033[0;36m')"
BOLD="$(printf '\033[1m')"
NC="$(printf '\033[0m')"

info()    { printf "${CYAN}ℹ ${NC}%s\n" "$*"; }
success() { printf "${GREEN}✔ ${NC}%s\n" "$*"; }
warn()    { printf "${YELLOW}⚠ ${NC}%s\n" "$*"; }
error()   { printf "${RED}✖ ${NC}%s\n" "$*" >&2; }
step()    { printf "\n${BOLD}── %s ──${NC}\n" "$*"; }

die() { error "$@"; exit 1; }

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

# ─── Prerequisite installation ───────────────────────────────────────────────

install_linux_prereqs() {
  if have dnf; then
    run_root dnf install -y git curl stow age zsh python3 python3-pip \
      ansible-core ansible-collection-community-general
    return
  fi

  die "Unsupported Linux package manager. This repo supports Fedora Linux (dnf/dnf5) only."
}

# ─── Repo clone / update ────────────────────────────────────────────────────

clone_or_update_repo() {
  mkdir -p "$(dirname "$REPO_DIR")"

  if [ -d "$REPO_DIR/.git" ]; then
    info "Updating existing dotfiles repo"
    git -C "$REPO_DIR" fetch --all --prune
    git -C "$REPO_DIR" checkout "$REPO_REF"
    git -C "$REPO_DIR" pull --ff-only origin "$REPO_REF"
  else
    info "Cloning dotfiles repo"
    git clone --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"
  fi
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  step "Bootstrap — $(detect_os)"
  info "Repo: ${REPO_URL} (${REPO_REF})"
  info "Target: ${REPO_DIR}"

  os="$(detect_os)"

  step "Installing prerequisites"
  case "$os" in
    Linux)
      install_linux_prereqs
      ;;
    *)
      die "Unsupported OS: $os. This repo supports Fedora Linux only."
      ;;
  esac
  success "Prerequisites installed"

  step "Cloning dotfiles"
  clone_or_update_repo
  success "Repo ready at ${REPO_DIR}"

  step "Handing off to apply"
  DOTFILES_PROFILE="$PROFILE" "$REPO_DIR/bin/.local/scripts/dot-apply"
}

main "$@"
