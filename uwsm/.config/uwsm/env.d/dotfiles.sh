# shellcheck shell=sh
# UWSM reads this as /bin/sh before launching Omarchy desktop apps. [F-SSH-AGENT]
if [ -z "${SSH_AUTH_SOCK:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi
