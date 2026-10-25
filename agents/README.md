# Central coding-agent configuration

Dotfiles owns portable instructions/skills, harness-specific configuration sources,
and pinned companion-tool recipes. It does **not** own credentials, sessions,
conversation history, caches or downloaded runtime packages. [D-AGENT-SKILLS]

## Layout and ownership

- `instructions/AGENTS.md`: shared user-wide guidance. This is separate from the
  repository-root `AGENTS.md`, which describes working on dotfiles. It originated
  from the existing Pi user guidance. T3 runtime routing lives in the `t3-subagents`
  skill, which the shared file points to, so non-T3 sessions don't carry it.
- `harnesses/claude/`: Claude settings delta and static statusline Stow package.
- `harnesses/pi/`: Pi settings/web/Sol-pi deltas and static PDF-extension Stow package. [D-PI-WEB]
- `harnesses/opencode/`: OpenCode settings delta (not a Stow package).
- Codex: `./install` prepends `project_doc_fallback_filenames = ["CLAUDE.md"]` to
  `~/.codex/config.toml` so Codex reads repos that only ship a CLAUDE.md.
- `skills/`: canonical portable workflow skills and bundled references.
- `tools/`: pyproject, uv lockfile, Python pin and disposable-project CLI tests.
- `sources.toml`: reviewed upstream repositories, refs, commits, license notes,
  vendored-file hashes, and the distinction between vendored and locally authored skills.

Static scripts/extensions use **per-file Stow links** from `harnesses/`, with
`--no-folding`. Mutable agent settings keep their narrow jq merges in the main
Omarchy installer; Pi's deltas are handled by the existing portable agent-config script. Neither mechanism owns whole agent directories. No auth,
MCP credentials, machine endpoints, model-catalog state or session files are
copied into dotfiles. Shared instructions and skills are **real managed copies**,
so they remain readable without this checkout.

## Install and verify

From the repository root:

```sh
make agents                 # shared instructions + static assets + skills + tools + Pi overlay
make verify-agents          # read-only/offline verification of that portable subset
make check-agent-updates    # networked report only; no downloads, edits or deployment
```

The main `./install` and `make verify` include the same operations on Omarchy.
Headless/non-Omarchy hosts use the standalone targets; they do not run unrelated
Omarchy setup or merge desktop-specific settings. Requirements: Linux, Python
3.11+, GNU Stow, uv, Git and network access for initial tool installation. The Pi
step additionally requires an existing Pi launcher, jq, and Node.js >=22.19/npm
on PATH; it never installs a system runtime. Pi configuration is included in
`make agent-config` / `make verify-agent-config`, not a separate command.
`PI_CODING_AGENT_DIR` selects an alternative Pi
root; `PI_BIN` optionally selects its launcher. Static Stow assets still target
Pi's default root. Individual `agent-config`, `verify-agent-config`, `agent-skills`,
and `verify-agent-skills` targets remain available.

Pi uses pinned pi-web-access 0.44.0 and Sol-pi's Pi 1.x compatibility commit.
The existing agent-config script merges all three JSON deltas, migrates the old npm Sol-pi
registration, and repairs cached vulnerable undici 8.x. It does not run a blanket
`npm audit fix` or alter Pi itself. Action Fusion, local ObservationPack, and
native Online Context Compact are on; Evidence-Preserving Reducer is off to
prevent separate model calls containing diagnostic logs. Cookies, automatic
hosted page-reader fallback, and hosted video analysis are off. Local observation
archives persist with session storage. Trusted project `sol-pi.json` overrides
replace the user-wide profile; review them before trust. [D-PI-WEB]

Shared instructions deploy to Pi's `~/.pi/agent/AGENTS.md`, Codex's
`~/.codex/AGENTS.md`, Claude's `~/.claude/CLAUDE.md` and OpenCode's
`~/.config/opencode/AGENTS.md`. Instruction files use copies rather than four
separately authored variants. Existing differing instructions stop installation;
review and save them before explicitly resolving the conflict.

Skills deploy to:

- `~/.agents/skills/`: the shared native location for Pi and Codex.
- `~/.claude/skills/`: compatibility copies, except `simplify` (keep Claude's native command).
- `~/.config/opencode/skills/`: compatibility copies pending positive discovery
  evidence for the installed OpenCode version. Latest docs advertise the shared
  root, but the installed v2.1.4 skill API returned no skills during the probe.
  Do not remove this compatibility path based on docs alone.

Codex's native shared-root discovery was verified through its local app-server
`skills/list` API, which reported both the shared copies and the old Codex-specific
copies. The latter were archived and removed to avoid duplicate selectors.
No provider/model call was used for discovery. Claude and Pi source references
stay untouched by the skill-copy deployment.

Restart agent sessions, or `/reload` in Pi. Ask for the skill by name; Pi supports
`/skill:ub-mode`, `/skill:ub-tools`, `/skill:t3-subagents`, `/skill:cleanup` and
`/skill:simplify` (with optional target/focus).

## Conflicts and drift

Edit canonical sources here, not deployed copies. State manifests under
`~/.local/state/dotfiles/` record installed instruction/skill hashes. Local edits,
unknown same-name resources, added files and symlinks cause a preflight failure;
unrelated resources remain untouched. Identical existing content can be adopted.
Save conflicts outside discovery paths before resolving them. Static Stow files
follow Stow's ordinary conflict rules; never use automatic `--adopt`.

Copies change only when installation runs. There is no background sync and no
automatic pruning of removed source skills. Deployed resources update one at a
time with incremental ownership records, not as a global transaction. Re-run an
interrupted install without concurrently editing its destinations.

The isolated tool environment lives at `~/.local/share/unclebob-tools/.venv/`,
with a recipe receipt beside it. `~/.local/bin/{crapper,dryer,mutator}` link to
that environment, not to the checkout. Mutator's otherwise undeclared crapper
runtime dependency is explicit. Installation runs real CLI smoke tests; offline
verification checks deployed copies, ownership, links and the recipe receipt,
not every installed package byte.

## Provenance and deliberate updates

`sources.toml` is the source inventory. CI and deployment validate its skill
inventory, vendored hashes and agreement with tool pins in both pyproject and
uv.lock. The pyproject remains uv's dependency input; validation prevents the
provenance manifest and executable recipe from silently diverging.

- `ub-mode` is vendored unchanged; upstream supplied no license file at the pin.
- `ub-tools` is one locally authored skill holding crapper/dryer/mutator usage
  notes under `references/<tool>/` (one listing entry instead of three), with upstream
  README/license references; their executable repositories are pinned separately.
- `simplify` is a locally authored behavioral counterpart of Claude Code 2.1.310,
  not a verbatim prompt export. Its provenance explains the four review angles,
  portable delegation, inline fallback and native-Claude exclusion.
- `uml-viewer` remains optional and is not installed.

`make check-agent-updates` resolves the explicitly declared upstream refs with
bounded `git ls-remote` calls. CURRENT means the ref matches the pin; CHANGED
means review is required, **not necessarily that it is a descendant upgrade**.
Network/ref failures are reported separately and return nonzero. Changed pins
are informational (exit zero). Local skills are never auto-replaced.

To update:

1. Save intended local edits and review upstream changes from the recorded pin.
2. For ub-mode, copy reviewed upstream files, then update its commit and SHA-256
   file inventory in `sources.toml`. Preserve the upstream license situation.
3. For tools, update both `sources.toml` and `tools/pyproject.toml`, then run
   `uv lock --project agents/tools`; use `--upgrade` only for a deliberate
   transitive dependency refresh. Refresh bundled README/licenses as needed.
4. For local skills, edit locally; simplify's reference-release review is manual.
5. Run `make ci`, `make agents`, and `make verify-agents`, then commit source,
   manifest, lockfile, docs and tests together in dotfiles. No automatic push.

Rollback restores the relevant `agents/` sources/helpers from a known-good
**dotfiles commit**, reruns those targets and commits the restoration. Never
discard differing live files merely to make rollback pass. Avoid concurrent CLI
runs while uv sync updates the environment.

## Verification and migration

CI covers managed-copy behavior, Stow orchestration, instruction conflicts,
state preservation, source/pin consistency and mocked update failures without
network access. CLI smoke tests exercise CRAP/duplication snapshots and real
bounded mutation testing on temporary projects, preserving original source.
The static harness package was additionally exercised with real Stow in a
throwaway home and on this host.

The initial pinned upstream tests passed 144 crapper, 80 dryer and 76 mutator
tests; two additional crapper tests need optional missing Babashka/zsh-UML
prerequisites. This is not evidence for every project's language runtime.

Previous standalone source/history, initial guidance and obsolete managed Codex
copies are preserved in timestamped directories under
`~/.local/state/dotfiles/migrations/`. Only known, unchanged managed content was
retired; no unrelated skills or agent state were removed. Legacy Stow links to
the former top-level `claude/` and `pi/` packages are retargeted only when their
exact old destinations match; a failed Stow operation restores removed legacy
links. Unknown links and real conflicting files still require explicit resolution.

To uninstall, first preserve edits, unstow only `claude`/`pi` from
`agents/harnesses`, and remove only the deployed files/directories recorded by
the two ownership manifests and the three runtime CLI links. Never remove whole
agent directories, their credentials, or unrelated state.
