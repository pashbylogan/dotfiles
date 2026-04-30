# Login-shell init. NB: distinct from the repo's .zsh_profile (which .zshrc
# sources for interactive shells); this fires only on login shells, e.g. the
# autologin TTY, never for terminals opened inside sway.

if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
    exec sway
fi
