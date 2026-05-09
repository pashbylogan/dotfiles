# Login-shell init. NB: distinct from the repo's .zsh_profile (which .zshrc
# sources for interactive shells); this fires only on login shells, e.g. the
# autologin TTY, never for terminals opened inside sway.

if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_DESKTOP=sway
    export DESKTOP_SESSION=sway
    exec sway
fi
