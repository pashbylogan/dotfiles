# Ubuntu SSH agent

These instructions apply to Ubuntu installations whose packaged systemd user
`ssh-agent.socket` listens at `%t/openssh_agent`. The Omarchy setup in the
[main README](../README.md#ssh--github) remains separate; its socket path differs.
Inspect the installed units with `systemctl --user cat ssh-agent.socket ssh-agent.service`
before configuring another distribution.

## Normal use

After reboot, load your default keys in a terminal:

```sh
ssh-add
```

For a specific key, use `ssh-add ~/.ssh/id_ed25519`. Enter its passphrase in
your terminal. Check loaded fingerprints with `ssh-add -l`. Local coding agents
can then use the same agent without prompting. Keys remain in memory until
removed, the agent exits, or the machine reboots.

`AddKeysToAgent yes` also lets an interactive SSH connection load a key after
prompting. Load keys first for unattended clients.

## Setup and recovery

Enable the packaged socket once:

```sh
systemctl --user enable --now ssh-agent.socket
```

For availability at boot without an interactive login, enable user lingering
with `loginctl enable-linger` (administrator authorization may be required).
Socket activation starts the agent on demand. Avoid a competing custom service
or starting a separate agent in each shell.

Shells and applications need `SSH_AUTH_SOCK` pointing to the packaged socket.
For a shell that lacks it:

```sh
export SSH_AUTH_SOCK="/run/user/$(id -u)/openssh_agent"
```

Publish this default through shell startup and the systemd user environment for
future sessions. Environment changes do not update already running processes.
A machine-local `Host *` entry in `~/.ssh/config.local` can additionally select
`IdentityAgent /run/user/%i/openssh_agent` for SSH clients without that environment.
This explicitly chooses the local agent over forwarded agents; `ssh-add` itself
uses `SSH_AUTH_SOCK`, not SSH configuration. Do not duplicate this setting in Git
repository overrides.

If the socket has been stopped:

```sh
systemctl --user start ssh-agent.socket
ssh-add
```

Inspect failures with `systemctl --user status ssh-agent.socket ssh-agent.service`.
Restarting the agent forgets loaded keys. `ssh-add -X` is for an agent explicitly
locked using `ssh-add -x`; loading keys after reboot uses plain `ssh-add`.
No custom unlock wrapper or saved passphrase is needed.

## Sources

- [OpenSSH ssh-add manual](https://man.openbsd.org/ssh-add.1)
- [OpenSSH SSH configuration manual](https://man.openbsd.org/ssh_config)
- [OpenSSH release notes: systemd-style socket activation](https://www.openssh.com/releasenotes.html)
- The installed Ubuntu units: `systemctl --user cat ssh-agent.socket ssh-agent.service`.
