# shell.sh — personal bash additions (repo-owned).
# Sourced LAST from the ~/.bashrc managed block, so these win where they
# intentionally overlap Omarchy. [D-SHELL-SEAM][D-SHELL-BASH][F-BASH-CHAIN]
#
# Kept deliberately minimal. Omarchy already provides (so we DON'T duplicate):
#   EDITOR=nvim (uwsm/default) + SUDO_EDITOR, starship prompt, zoxide `cd`,
#   eza `ls`, mise runtimes, and aliases t / g / gcm / gcam / n / ga / gd /
#   tdl / fip. Node comes from mise (no nvm).
# Install tools via official Omarchy methods (pacman / AUR / mise) so they land
# on PATH. The ~/apps/* blocks below are GUARDED FALLBACKS for manual installs
# and stay inert otherwise. Secrets/host values live in shell.local.sh. [D-SECRETS-LOCAL]

# ── aliases (additive to Omarchy's set) ──────────────────────────────────────
alias de='deactivate'
alias uf='uvx ruff format '
alias vim='nvim'
alias ta='tmux attach -t'        # attach to a named session, e.g. `ta portal`
alias tn='tmux new-session'
alias tl='tmux list-sessions'
alias gs='git status'
alias gap='git add -p'
alias sz='source ~/.bashrc'

# ── git worktrees (own verbs; Omarchy's ga/gd only create NEW branches) ──────
wta()  { git worktree add "$@"; }
wtl()  { git worktree list; }
wtp()  { git worktree prune; }
wtr()  { git worktree remove "$@"; }
cdwt() {
  [ -z "$1" ] && { echo "Usage: cdwt <substring>"; return 1; }
  local d; d="$(git worktree list | grep -F -- "$1" | awk 'NR==1{print $1}')"
  [ -n "$d" ] && cd "$d" || { echo "cdwt: no worktree matching '$1'"; return 1; }
}

# ── python venv: prefer local .venv, else the central uv base venv ───────────
ve() {
  local local_activate=".venv/bin/activate"
  local base_activate="$HOME/apps/uv/central_venv_repo/base/.venv/bin/activate"
  if   [ -f "$local_activate" ]; then . "$local_activate"
  elif [ -f "$base_activate"  ]; then . "$base_activate"
  fi
}
# uv: prefer mise/pacman uv on PATH. Only a manual ~/apps/uv install needs these
# env overrides, so they are guarded (fallback only).
if [ -d "$HOME/apps/uv" ]; then
  uv_dir="$HOME/apps/uv"
  export UV_UNMANAGED_INSTALL="$uv_dir" UV_INSTALL_DIR="$uv_dir" \
         UV_TOOL_DIR="$uv_dir/tools" UV_PYTHON_INSTALL_DIR="$uv_dir/python" \
         UV_TOOL_BIN_DIR="$uv_dir/bin" UV_CACHE_DIR="$uv_dir/cache" \
         UV_PYTHON_BIN_DIR="$uv_dir/python/bin"
  unset uv_dir
fi

# ── GCP / gcloud ─────────────────────────────────────────────────────────────
# Prefer `omarchy pkg aur add google-cloud-cli` (puts gcloud + completions on
# PATH). gssh works with any gcloud on PATH; the sourcing below only handles a
# manual ~/apps/google-cloud-sdk fallback install.
gssh() {
  local ip
  ip="$(gcloud compute instances describe "$1" --format='get(networkInterfaces[0].networkIP)' "${@:2}")"
  echo "$ip"
  ssh "$ip"
}
if [ -d "$HOME/apps/google-cloud-sdk" ]; then
  [ -f "$HOME/apps/google-cloud-sdk/path.bash.inc" ]       && . "$HOME/apps/google-cloud-sdk/path.bash.inc"
  [ -f "$HOME/apps/google-cloud-sdk/completion.bash.inc" ] && . "$HOME/apps/google-cloud-sdk/completion.bash.inc"
fi
[ -d "$HOME/apps/cloud-sql-proxy" ] && case ":$PATH:" in
  *":$HOME/apps/cloud-sql-proxy:"*) ;; *) export PATH="$PATH:$HOME/apps/cloud-sql-proxy" ;;
esac

# ── VPN: switch between WireGuard (cypris) and a Tailscale exit node ──────────
exitnode() {
  if [ "$1" = "up" ]; then
    tailscale exit-node suggest | awk -F ": " '/Suggested exit node/ {print $2}' \
      | xargs -I {} sudo tailscale set --exit-node={} --exit-node-allow-lan-access=true
  elif [ "$1" = "down" ]; then
    sudo tailscale set --exit-node=
  else
    echo "Usage: exitnode up|down"
  fi
}
vpns() {
  local wg_up=false ts_up=false
  ip link show cypris &>/dev/null && wg_up=true
  tailscale status --json 2>/dev/null | grep -q '"ExitNode": true' && ts_up=true
  if   $wg_up; then echo "wireguard -> mullvad..."; sudo wg-quick down cypris; exitnode up
  elif $ts_up; then echo "mullvad -> wireguard..."; exitnode down; sudo wg-quick up cypris
  else echo "Error: neither wireguard nor mullvad is active"; return 1
  fi
}
