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
   persistent deny-lists applied by this repo. [D-BASELINE][D-WEBAPP]

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
   below), then re-run `./install` to create their Stow links. The shell and SSH
   overrides are picked up on their next invocation; `dotfiles_local.lua` is
   loaded on the next Hyprland reload.
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
11. **ChatGPT and Hermes** — sign in to each desktop app. `./install` uses
    Omarchy menu → Install → AI → ChatGPT / Hermes, so Hermes also receives its
    managed runtime and current Omarchy theme. [F-APP-CHANNELS]
12. **Spotify** — sign in to your account. Installed from Quattro's supported
    sync-repo package by `./install`, pinned to workspace 10.

13. **Pi** — run `pi`, then `/login openai` → **Sign in with ChatGPT**.
    The overlay installs the pinned web-access extension and configures it;
    OAuth credentials and plan authorization remain a one-time step per machine.
    Start a fresh Pi session after installation. [D-PI-WEB]

### Work-specific (optional)

14. **WireGuard `cypris` tunnel** — drop the work-provided config at
    `/etc/wireguard/cypris.conf` (mode 600, root-owned). The `vpns()` and
    `exitnode()` helpers you author in machine-local `shell.local.sh` (see
    `shell.local.sh.example`) then toggle it against the Tailscale
    exit-node path; without `cypris.conf` (or without an active VPN to flip
    from) `vpns` prints an error and returns non-zero — no state change,
    but not a silent no-op.

## Per-machine overrides

Copy each `.example` to the listed gitignored path inside this checkout and fill
in secrets/host values. Re-run `./install` to link the real files into `~`.
[D-SECRETS-LOCAL]

| Copy this                                       | To this gitignored path                         | For                                  |
| ---                                             | ---                                             | ---                                  |
| `bash/.config/dotfiles/shell.local.sh.example`  | `bash/.config/dotfiles/shell.local.sh`          | secrets, project IDs, device serials |
| `ssh/.ssh/config.local.example`                 | `ssh/.ssh/config.local`                         | machine-specific ssh hosts           |
| `hypr/.config/hypr/dotfiles_local.lua.example` | `hypr/.config/hypr/dotfiles_local.lua` | device-specific Hyprland Lua (e.g. mouse accel) |

## Daily use

### Pi coding agent

`./install` ensures Pi's Omarchy-owned launcher exists through
`omarchy mise install pi`. It uses that launcher to provision the pinned
`pi-web-access@0.35.0` extension when missing or at the wrong version, downloading
Pi on a fresh machine. Quattro's updater owns subsequent mise-backed agent
updates. Pi uses the shared repo-root `AGENTS.md` guidance.
[F-APP-CHANNELS]

To select Pi for Omarchy's agent shortcut, use Omarchy menu → Setup → Defaults
→ Agent → Pi. Authentication and session state stay local to the machine.

The `pi/` overlay sets the default model to `openai/gpt-6.1-sol` and uses
`gpt-6-luna` for web search and page answers through your ChatGPT login. Search
falls back to keyless Exa; page fetching falls back to keyless Jina Reader.
Images, PDFs, GitHub content, source checks, and stored-content retrieval are
enabled. PDF extraction stays local, with a stowed compatibility extension for
Pi's bundled runtime. Browser-cookie access stays off. [D-PI-WEB]

`./install` merges the settings without tracking credentials or session state,
installs Node through Omarchy if npm is missing, and stows the PDF fix.
`make verify` checks the overlay without launching Pi or contacting providers.
Implementation details and compatibility findings are documented in
[the Pi decision](docs/decisions.html#D-PI-WEB).

Scanned PDFs need OCR or visual inspection; local extraction is limited to
20 MB and 100 pages. Video frame extraction uses Quattro's ffmpeg/yt-dlp tools;
full video analysis requires separate Gemini credentials. Exa and Jina's keyless
services have usage limits, and Jina receives URLs when direct fetching fails.

### Operations

| Command                | What it does                                                 |
| ---                    | ---                                                          |
| `./install`            | Re-converge the overlay                                      |
| `make ci`              | Lint + format check + docs integrity (run before committing) |
| `make fmt`             | Auto-fix formatting (shfmt + prettier)                       |
| `make verify`          | Live overlay health check (read-only)                        |
| `make update`          | Omarchy packages + mise agents + uv + unused mise cleanup, then verification |
| `make update-firmware` | Firmware only (fwupd) — opt-in                               |
| `pkg-residue <package>` | Read-only audit for package leftovers after removal [D-PKG-REMOVE] |

Network diagnostics are available through `nmap`, installed from Arch `extra`
via `packages.txt` and the repo's normal `omarchy pkg add` convergence path.
[D-PKG-REMOVE][F-CLI]

### Guest Wi-Fi login

Connect to the guest network, then run `wifi-login` if no sign-in page appears.
The stowed command discovers HTTP, meta-refresh, or literal JavaScript portal
redirects outside the browser, then opens the login URL through
`omarchy launch browser` (whatever your selected default browser is).
It does not switch networks, change DNS/VPN/browser settings, accept terms,
or submit credentials. Use `wifi-login --print` to inspect the URL without
opening it; treat portal URLs as temporary and potentially sensitive.
[D-WIFI-LOGIN]

If NetworkManager reports full internet access, it opens nothing. Unsupported
inline login pages or computed JavaScript redirects need manual browser access;
HTTP-only portals may still show the browser's HTTPS-first warning. Certificate
verification stays enabled — do not bypass certificate errors.

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
pseudo-TTY orphan prompt. Then runs `omarchy update -y`, which owns package,
migration, and mise-backed agent updates, followed by `uv self update` because
uv remains outside mise, filtered mise cleanup, and `make verify`. Update and cleanup
failures are warned so remaining work and read-only verification still run.
[F-CLI][D-CI]

```sh
make update-firmware
```

Firmware only: `omarchy update firmware` (fwupd). It stays opt-in because
firmware updates — unlike packages or self-managed tools — can have
device-specific prompts and reboot/power-cycle outcomes. JetBrains IDEs managed
by Toolbox still update via Toolbox's own UI. [F-CLI]

### Mise cleanup

`make update` removes unused mise versions after updates while retaining versions
with detected live consumers.
It groups retained versions with process names and PIDs and summarizes removed
and kept counts using the repo's normal status markers; you can keep working
and let later cleanup runs remove them once their consumers exit. Skipping busy
versions is a successful no-op, not an error.

Candidates come from `mise ls --prunable --json`, preserving mise's config/stub
reference tracking. The helper checks same-user Linux `/proc` executable paths,
working directories, script arguments, memory maps, and open files. Before each
removal it refreshes candidate eligibility and checks live consumers again, then
calls `mise uninstall --yes <tool>@<version>` for that exact version. It never
hands mise a broad removal set that could include the retained versions.

Preview without deleting anything:

```sh
/usr/bin/python3 .github/scripts/prune_mise.py --dry-run
```

The process check is best-effort: it reports protected processes it cannot fully
inspect and cannot cover other users, future imports, or launches between the
check and deletion. It is a snapshot, not a launch lock.
[D-CI]

Omarchy deliberately keeps `upgrade.auto_prune=false` so updates cannot remove
install directories out from under live sessions. Our cleanup adds live-consumer
filtering to `make update`; mise's unused-version tracking does not prove a
version has no running consumers. Mise also supports deferred upgrade pruning (a 24-hour grace
period by default), but that delay is not a running-process check. Cleanup covers
existing unused versions, including those left by Omarchy's lazy wrappers.
