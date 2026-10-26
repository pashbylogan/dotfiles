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
    by `./install` from Omarchy's sync repository (via `packages.txt`) and pinned
    to workspace 3 in `hypr/dotfiles.lua`. If huddles or screen sharing regress in the native app,
    use Slack in the browser as the fallback; do not add a tray dependency unless
    the local tray behavior stops working. [F-APP-CHANNELS]
11. **ChatGPT and T3 Code** — open each desktop app and complete its
    account/provider setup. `./install` uses Omarchy menu → Install → AI →
    ChatGPT / T3 Code. T3 Code receives and selects the current Omarchy theme.
    Hermes runs on Saruman; the local desktop is denied in `packages.remove.txt`.
    Its browser workspace is deferred until an official Docker release includes
    it; the existing dashboard is not that workspace. [F-APP-CHANNELS]
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
`pi-web-access@0.44.0` extension and a commit-pinned Sol-pi revision when missing
or incorrect, downloading Pi on a fresh machine. Quattro's updater owns subsequent mise-backed agent
updates. Pi uses the shared repo-root `AGENTS.md` guidance.
[F-APP-CHANNELS]

To select Pi for Omarchy's agent shortcut, use Omarchy menu → Setup → Defaults
→ Agent → Pi. Authentication and session state stay local to the machine.

The `agents/harnesses/pi/` overlay sets the default model to `openai/gpt-6.1-sol` and uses
`gpt-6-luna` for web search and page answers through your ChatGPT login. Search
falls back to keyless Exa. Page fetching is direct HTTP only: automatic hosted
fallbacks (including Jina) are disabled. Images, PDFs, GitHub content, source
checks, and stored-content retrieval are enabled. PDF extraction stays local,
with a stowed compatibility extension for Pi's bundled runtime. Browser-cookie
access and hosted video analysis stay off. Search queries and explicit page-answer
requests still go to their selected providers. [D-PI-WEB]

Sol-pi is pinned to upstream commit `219568034fa54ed121ede80961655e33dfb9d0e3`
(the Pi 1.x compatibility revision). Action Fusion, local ObservationPack, and
Online Context Compact are enabled. **Evidence-Preserving Reducer is disabled**:
it would send diagnostic logs to a separate model call. ObservationPack archives
tool output locally under Pi's session storage; native compaction uses the
existing Pi model route. Trusted project `.pi/sol-pi.json` replaces the user-wide
profile, so inspect overrides before trusting a project. Restart Pi after config
changes.

`./install` merges settings without tracking credentials/session state, installs
Node through Omarchy if npm is missing, and stows the PDF fix. Pi's package and
configuration setup is part of the existing `make agents` / `make agent-config`
flow; portable hosts require Pi, Git, jq, and Node.js >=22.19/npm already on PATH.
Both paths repair vulnerable cached undici 8.x within the extension's supported
dependency range. `make verify-agents` and `make verify` inspect files without
launching Pi or contacting providers.
Implementation details and compatibility findings are documented in
[the Pi decision](docs/decisions.html#D-PI-WEB).

Scanned PDFs need OCR or visual inspection; local extraction is limited to
20 MB and 100 pages. Video frame extraction uses Quattro's ffmpeg/yt-dlp tools;
hosted video analysis is disabled. Exa's keyless search service has usage limits.
Pages that fail direct fetching need manual inspection rather than being forwarded
to another hosted reader.

### Shared coding-agent skills

`agents/` owns shared user instructions, portable skills, reviewed source pins,
and harness-specific static assets/settings deltas. Static scripts/extensions
use per-file Stow links from `agents/harnesses/`; shared instructions and skills
use managed **copies**, while mutable settings keep narrow jq merges. Portable
`make agents` also converges Pi's packages and privacy-preserving settings; Pi,
Git, jq, and Node.js >=22.19/npm must already be on PATH. Auth and
runtime state are never imported. Local edits or unknown conflicts stop deployment;
unrelated files remain untouched. [D-AGENT-SKILLS]

On non-Omarchy/headless hosts, install just this portable subset:

```sh
make agents
make verify-agents
make check-agent-updates  # explicit upstream check; no files changed
```

Restart agent sessions, or `/reload` in Pi. Source, provenance, controlled updates,
rollback, and conflict resolution are documented in [`agents/README.md`](agents/README.md).
The isolated tool environment is disposable local state; dotfiles is the only
source repository. The optional UML viewer is not installed. Codex and Pi use
`~/.agents/skills/` directly; OpenCode retains compatibility copies until the
installed version's shared-root discovery is positively verified.

Ask another agent to use `simplify` (Pi: `/skill:simplify [target or focus]`) to
review changes from four cleanup angles in parallel, deduplicate findings, and
apply behavior-preserving fixes. If subagents are unavailable, it covers all
four angles inline and reports the fallback. Claude Code keeps its native
`/simplify`; no competing personal skill is installed there.

### T3 Code

`./install` installs T3 Code through `omarchy install ai t3-code` when
`t3code-bin` is missing. The supported flow installs Omarchy's sync-repo package,
selects the Omarchy palette, and opens the app. Subsequent theme changes are
managed by Omarchy; package updates arrive through `make update`. `make verify`
checks that the package is installed. [F-APP-CHANNELS]

Use the packaged `t3` CLI or launch T3 Code from the Apps menu. Add projects and
connect your providers in the app; the existing Omarchy agent wrappers remain
the CLI installation path. T3 Code's `~/.t3/` state and
`~/.config/t3code-v2/` Electron profile stay machine-local, including accounts,
provider settings, project registrations, sessions, and worktrees. This repo's
`AGENTS.md` remains the project guidance for the selected coding agent.

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
| `security-scan`        | Read-only ClamAV + posture scan (see [Security scans](#security-scans)) |

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

`security-scan` (stowed from `bin/.local/bin/`) is the read-only whole-machine
sweep. It refreshes ClamAV signatures, scans the filesystem, and runs posture
checks: signature age and daemon state, non-loopback TCP listeners, privileged
files (SUID/SGID/capabilities) that no package owns, world-writable files in
system paths, empty-password accounts, sshd exposure, and package state. It
never deletes, quarantines, or reconfigures anything — review detections
instead of acting automatically. [D-SECURITY-SCAN][F-MALWARE-SCANNER]

```sh
security-scan                      # requests sudo; full sweep with fresh signatures
security-scan --quick              # home + /tmp, /var/tmp, /dev/shm
security-scan --skip-malware       # fast posture checks only
security-scan --no-freshclam       # requests sudo; offline full sweep
```

A full sweep requests sudo automatically so unreadable paths cannot quietly
weaken a "clean" result; `--quick` and `--skip-malware` stay unprivileged.
Run `security-scan` directly: sudo's restricted PATH may not include the
stowed command in `~/.local/bin`. Logs land in
`~/.local/state/security-scan/<timestamp>/` and are owned by the invoking user
even under `sudo`. A full sweep takes tens of minutes, and ClamAV's size limits
still skip files over 100 MB and containers over 400 MB. Exit status is `0`
clean, `1` detections or an incomplete scan, and `2` usage error; `--strict`
also fails on posture findings.

ClamAV comes from Arch `extra` through `packages.txt`, and no daemon or
on-access service is enabled. It is a file-signature scanner, not a complete
endpoint-security suite: a clean result complements process, persistence,
browser-permission, download, and network checks, and does not prove that a
machine was never compromised.

## Updates

```sh
make update
```

Run in a terminal. `omarchy update -y` owns package, migration, mise-backed
agent updates, and orphan review; on Omarchy 4.0.5 it can still ask whether to
remove orphans despite `-y`. There is no separate repo preflight or automatic
package-removal policy. Review the proposed removals and decline if unsure.
Then run `uv self update` because uv remains outside mise, native mise cleanup,
and `make verify`. Update and cleanup failures are warned so remaining work and
read-only verification still run.
[F-CLI][D-CI]

```sh
make update-firmware
```

Firmware only: `omarchy update firmware` (fwupd). It stays opt-in because
firmware updates — unlike packages or self-managed tools — can have
device-specific prompts and reboot/power-cycle outcomes. JetBrains IDEs managed
by Toolbox still update via Toolbox's own UI. [F-CLI]

### Mise cleanup

`make update` calls `mise prune --tools --yes`. This requires the native
running-process protection verified in mise **2026.10.13** (shipped on our
updated Omarchy 4.0.5 machine). The wrapper skips cleanup on older mise,
even if the preceding update failed. Mise owns config/stub reference tracking,
running-process detection, removal,
and reporting. `--tools` leaves tracked-config housekeeping alone.

Preview without deleting anything:

```sh
mise prune --tools --dry-run
```

Native mise retains versions used by running executables or absolute script
paths, including conservatively retaining versions behind a runtime symlink
retargeted after a process started. This replaces our custom Python scanner.
It is not identical: a working directory, open file, mapped library, or relative
script path alone does not protect a version. Uninspectable processes and
processes starting after the scan are not guaranteed protection. Close unusual
consumers before cleanup; this is not a launch lock. [D-CI]

Keep Omarchy's `upgrade.auto_prune=false`: upgrades and this explicit cleanup
step remain separate. There is no repo-owned process scanner or manual
`mise uninstall` loop.
