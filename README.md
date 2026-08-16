# Dotfiles — a minimal personal overlay on Omarchy

A small, idempotent overlay on top of [Omarchy](https://omarchy.org/)
(Arch + Hyprland). Omarchy installs and seeds the desktop; this repo
layers my customizations on top via official paths. One convergence script:
`install`. [D-SCRIPTS-MINIMAL]

> **Design docs:** open [`docs/index.html`](docs/index.html) for
> architecture, decisions, findings, and traceability. This README is
> the usage surface only.

## Fresh-machine setup

End-to-end steps to take a freshly-imaged Omarchy box to the state this repo
represents. Each numbered step is necessary in order.

### Omarchy base

1. **Install Omarchy.** The installer prompts for full name + email and writes
   them to `~/.config/git/config` as `user.name` / `user.email`, so no
   follow-up `git config` is needed.
2. **Keep the stock Quattro baseline.** Do not run the broad Remove
   Preinstalled flow: Quattro owns retained apps, OmaCalc, and its lazy agent
   wrappers. `packages.remove.txt` and `webapps.remove.txt` are the explicit
   persistent deny-lists applied by this repo. [D-BASELINE][D-WEBAPP][F-BASELINE]

### SSH + GitHub

3. **Generate an ed25519 keypair** — `ssh/.ssh/config` hard-codes
   `IdentityFile ~/.ssh/id_ed25519`, so pin the path explicitly:
   ```sh
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "your@email.com"
   ```
4. **Enable the systemd ssh-agent socket** — Omarchy ships it disabled; this
   overlay publishes its socket through UWSM for Omarchy-launched apps and
   terminals, but the socket needs a one-time enable per machine.
   [F-SSH-AGENT]
   ```sh
   systemctl --user enable --now ssh-agent.socket
   systemctl --user is-enabled ssh-agent.socket
   ```
   If you're provisioning over SSH before logging in to the GUI seat
   (headless first boot), `systemctl --user` will fail with
   "Failed to connect to bus" until the user manager is lingering:
   ```sh
   loginctl enable-linger "$USER"
   ```
5. **Add the public key to GitHub** at <https://github.com/settings/keys>:
   ```sh
   wl-copy < ~/.ssh/id_ed25519.pub   # or: cat ~/.ssh/id_ed25519.pub
   ```

### Install the overlay

6. **Clone and run install.**
   ```sh
   git clone git@github.com:<you>/dotfiles.git ~/Projects/dotfiles
   cd ~/Projects/dotfiles
   ./install
   ```
   The very first `git clone` runs before this repo's `~/.ssh/config`
   (with `AddKeysToAgent yes`) is stowed, so ssh prompts for the passphrase
   directly. Once `./install` finishes and you have logged into a new Omarchy
   session (step 8), load the key into the agent so subsequent ssh use is
   once-per-session:
   ```sh
   ssh-add ~/.ssh/id_ed25519
   ```
   `./install` is idempotent — re-run after editing a fragment, after an
   Omarchy refresh, or to apply newly-added entries in either deny-list. It also
   selects Brave Origin and Ghostty through Quattro's supported install flows.
   [D-IDEMPOTENT][D-PKG-REMOVE][D-WEBAPP][D-BROWSER-DEFAULT]
7. **Create per-machine overrides** (see [Per-machine overrides](#per-machine-overrides)
   below). `shell.local.sh` and `~/.ssh/config.local` are picked up on next
   shell / ssh invocation; `dotfiles_local.lua` is loaded automatically after
   re-running `./install` to create its Stow link.
8. **Log out and back into Omarchy** so UWSM reads the stowed
   `~/.config/uwsm/env.d/dotfiles.sh` fragment. Obsidian and terminals launched
   from the Omarchy session then inherit the same `SSH_AUTH_SOCK`. Quick check:
   ```sh
   printf '%s\n' "$SSH_AUTH_SOCK"   # expected: /run/user/<uid>/ssh-agent.socket
   ssh-add -l || ssh-add ~/.ssh/id_ed25519
   ```

### External services

Not part of the overlay itself, but required to reach the same working state.
Each ends in an interactive auth flow.

9.  **Tailscale** — run `omarchy-install-tailscale` (or Omarchy menu → Install
    → Tailscale). It pacman-installs tailscale, enables `tailscaled.service`,
    and runs `tailscale up --accept-routes`, which **blocks** until you
    complete the browser auth flow it prints — don't Ctrl-C while it looks
    frozen; just finish the login and the command returns.
10. **Slack** — sign in to your workspace. Native `slack-desktop` is installed
    by `./install` (via `packages.aur.txt`) and pinned to workspace 3 in
    `hypr/dotfiles.lua`. If huddles or screen sharing regress in the native app,
    use Slack in the browser as the fallback; do not add a tray dependency unless
    the local tray behavior stops working. [F-APP-CHANNELS]
11. **Spotify** — sign in to your account. Installed from Quattro's supported
    sync-repo package by `./install`, pinned to workspace 10.

### Work-specific (optional)

12. **WireGuard `cypris` tunnel** — drop the work-provided config at
    `/etc/wireguard/cypris.conf` (mode 600, root-owned). The `vpns()` and
    `exitnode()` helpers in `shell.sh` then toggle it against the Tailscale
    exit-node path; without `cypris.conf` (or without an active VPN to flip
    from) `vpns` prints an error and returns non-zero — no state change,
    but not a silent no-op.

## Per-machine overrides

Copy each `.example` and fill in secrets/host values; the real files are
gitignored and sourced automatically. [D-SECRETS-LOCAL]

| Copy this                                       | To                                       | For                                                                                          |
| ---                                             | ---                                      | ---                                                                                          |
| `bash/.config/dotfiles/shell.local.sh.example`  | `~/.config/dotfiles/shell.local.sh`      | secrets, project IDs, device serials                                                         |
| `ssh/.ssh/config.local.example`                 | `~/.ssh/config.local`                    | machine-specific ssh hosts                                                                   |
| `hypr/.config/hypr/dotfiles_local.lua.example` | `~/.config/hypr/dotfiles_local.lua` | device-specific Hyprland Lua (e.g. mouse accel) — re-run `./install` after creating |

## Daily use

| Command                | What it does                                                 |
| ---                    | ---                                                          |
| `./install`            | Re-converge the overlay                                      |
| `make ci`              | Lint + format check + docs integrity (run before committing) |
| `make fmt`             | Auto-fix formatting (shfmt + prettier)                       |
| `make verify`          | Live overlay health check (read-only)                        |
| `make update`          | Omarchy packages + Quattro-managed mise agents + uv, then verification |
| `make update-firmware` | Firmware only (fwupd) — opt-in                               |
| `pkg-residue <package>` | Read-only audit for package leftovers after removal [D-PKG-REMOVE] |

Network diagnostics are available through `nmap`, installed from Arch `extra`
via `packages.txt` and the repo's normal `omarchy pkg add` convergence path.
[D-PKG-REMOVE][F-CLI]

## Security scans

ClamAV is installed from Arch `extra` through `packages.txt`, but no ClamAV
daemon or on-access service is enabled. Refresh its signatures immediately
before an explicit scan; review detections rather than auto-removing files:
[F-MALWARE-SCANNER]

```sh
sudo freshclam
clamscan --recursive --infected "$HOME"
```

ClamAV is a file-signature scanner, not a complete endpoint-security suite. A
clean result complements process, persistence, browser-permission, download,
and network checks; it does not prove that a machine was never compromised.

## Updates

```sh
make update
```

Refuses to start while `pacman -Qdtq` reports orphans, avoiding Omarchy's
pseudo-TTY orphan prompt (especially the one-time post-Elephant
`libqalculate` case). Then runs `omarchy update -y`, which owns package,
migration, and mise-backed agent updates, followed by `uv self update` because
uv remains outside mise and `make verify`. Update failures are warned so the
remaining channels and read-only verification still run. [F-CLI]

```sh
make update-firmware
```

Firmware only: `omarchy update firmware` (fwupd). It stays opt-in because
firmware updates — unlike packages or self-managed tools — can have
device-specific prompts and reboot/power-cycle outcomes. JetBrains IDEs managed
by Toolbox still update via Toolbox's own UI. [F-CLI]
