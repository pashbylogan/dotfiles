# Sourced fragment: tell shellcheck the dialect and allow guarded optional sources.
# shellcheck shell=bash
# shellcheck disable=SC1090,SC1091,SC2015
# Sourced LAST from the ~/.bashrc managed block, so these win where they
# intentionally overlap Omarchy. [D-SHELL-SEAM][D-SHELL-BASH][F-BASH-CHAIN][D-CARRY-SET]
# Generic, portable defaults only; personal and device-specific aliases,
# functions, and keybinds live in the gitignored shell.local.sh, sourced after
# this.

# ── aliases ──────────────────────────────────────────────────────────────────
alias de='deactivate'
alias ta='tmux attach -t'
alias tn='tmux new-session'
alias tl='tmux list-sessions'
alias sz='source ~/.bashrc'

# ── git (oh-my-zsh-style) ──────────────────────────────────────────────────────
alias gs='git status'
alias gap='git add -p'
alias gco='git checkout'
alias gp='git push'
alias gl='git pull'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gsta='git stash push'
alias gstp='git stash pop'
# `gd` shadows Omarchy's destructive gd() worktree-remove with `git diff`. It MUST
# be a function, not an alias: an active `gd` alias makes bash alias-expand
# Omarchy's `gd() {` on re-source (sz) into a syntax error. Sourced last, ours wins.
gd() { git diff "$@"; }

# ── git worktrees ────────────────────────────────────────────────────────────
# Keep worktree verbs separate from Omarchy's new-branch aliases.
wta() { git worktree add "$@"; }
wtl() { git worktree list; }
wtp() { git worktree prune; }
wtr() { git worktree remove "$@"; }
cdwt() {
  [ -z "$1" ] && {
    echo "Usage: cdwt <substring>"
    return 1
  }
  local d
  d="$(git worktree list | grep -F -- "$1" | awk 'NR==1{print $1}')"
  [ -n "$d" ] && cd "$d" || {
    echo "cdwt: no worktree matching '$1'"
    return 1
  }
}

# ── python ───────────────────────────────────────────────────────────────────
# Activate a project-local venv; uv itself is installed natively (on PATH).
ve() {
  [ -f ".venv/bin/activate" ] && . ".venv/bin/activate"
}
