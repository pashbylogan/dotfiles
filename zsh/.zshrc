# Load profile-provided PATH before interactive setup. Ghostty starts zsh as an
# interactive non-login shell, so prompt/tools installed under ~/apps are not
# visible until ~/.zsh_profile has been sourced.
if [[ -f ~/.zsh_profile ]]; then
  source ~/.zsh_profile
fi

# Deduplicate PATH entries on re-source
typeset -U path

# ─── Completion ──────────────────────────────────────────────────────────────

autoload -Uz compinit
compinit -C

zmodload -i zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/compcache"
zstyle ':completion:*' list-colors ''

# ─── History ─────────────────────────────────────────────────────────────────

HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify

# ─── Key bindings ────────────────────────────────────────────────────────────

bindkey -e

# History prefix search (type partial command + up/down)
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Navigation
bindkey '^[[H'    beginning-of-line      # Home
bindkey '^[[F'    end-of-line            # End
bindkey '^[[3~'   delete-char            # Delete
bindkey '^[[1;5C' forward-word           # Ctrl-Right
bindkey '^[[1;5D' backward-word          # Ctrl-Left
bindkey '^[[Z'    reverse-menu-complete  # Shift-Tab

# Edit command in $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line

# ─── Options ─────────────────────────────────────────────────────────────────

setopt auto_cd
setopt auto_pushd
setopt globdots
setopt interactive_comments

# ─── Editor ──────────────────────────────────────────────────────────────────

export EDITOR='nvim'
export VISUAL='nvim'

# ─── Prompt (Starship) ──────────────────────────────────────────────────────

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ─── fzf ─────────────────────────────────────────────────────────────────────

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

# ─── fnm ─────────────────────────────────────────────────────────────────────

export FNM_DIR="$HOME/apps/fnm"
if [[ -x "$FNM_DIR/fnm" ]]; then
  path+=("$FNM_DIR")
  eval "$("$FNM_DIR/fnm" env --shell zsh --use-on-cd --version-file-strategy=recursive)"
fi

# ─── UV ──────────────────────────────────────────────────────────────────────

uv_dir="${DOTFILES_APPS_ROOT:-$HOME/apps}/uv"
# UV_INSTALL_DIR / UV_UNMANAGED_INSTALL must point at the directory the uv
# binary actually lives in (matches the Ansible installer in roles/user_tools)
# so a later `uv self update` rewrites $uv_dir/bin/uv rather than $uv_dir/uv.
export UV_UNMANAGED_INSTALL="$uv_dir/bin"
export UV_INSTALL_DIR="$uv_dir/bin"
export UV_TOOL_DIR="$uv_dir/tools"
export UV_PYTHON_INSTALL_DIR="$uv_dir/python"
export UV_TOOL_BIN_DIR="$uv_dir/bin"
export UV_CACHE_DIR="$uv_dir/cache"
export UV_PYTHON_BIN_DIR="$uv_dir/python/bin"
