# AGENTS.md

Project guidance for coding agents. This file is intentionally short: route to
the repo docs for durable context, and keep only rules agents need in most tasks.
[F-AGENT-GUIDANCE]

## Start Here

- Read `README.md` for the operator-facing overview.
- For architecture and rationale, open `docs/index.html`, then follow
  Architecture, Decisions, Findings, and Trace.
- Use `docs/registry.json` to find every file governed by a `D-*` or `F-*`
  decision/finding ID.

## Omarchy Sources

- For desktop or Omarchy customization, use the available `omarchy` skill. On
  Quattro its packaged source is
  `/usr/share/omarchy/default/agents/skills/omarchy/SKILL.md`.
- Prefer Omarchy-native features: `omarchy` commands, Omarchy menu flows,
  supported hooks, and user-owned config under `~/.config/`.
- Official docs start at `https://omarchy.org/` and the manual at
  `https://learn.omacom.io/2/the-omarchy-manual`; check Dotfiles first for
  config ownership rules.
- Read `~/.local/share/omarchy/` when needed to understand behavior, but do not
  edit it for user customization.

## Commands

- `make ci` runs the full static gate: shellcheck, shfmt, prettier, docs integrity.
- `make fmt` auto-formats shell and docs files.
- `make tools` shows required tools and Omarchy install hints.
- `make verify` checks the live machine overlay without changing it.

Run `make ci` after edits that affect tracked code, shell, docs, package
manifests, or traceability metadata.

## Comment Conventions

- Comments should explain why, not restate what the next line does.
- Keep comments to 1-2 lines unless the local safety context cannot be moved.
- Long operational context belongs in `docs/`, then link it with a `D-*` or
  `F-*` token where the behavior is enforced.
- Section headers such as `# ── prerequisites ──` are allowed in longer scripts
  or config files when they improve scanning.
- Keep traceability tokens in code comments when `docs/registry.json` lists the
  file under `code_paths`; `make ci` enforces those tokens.
- Prefer comments for safety constraints, precedence/load-order rules,
  idempotency, external tool quirks, and non-obvious compatibility choices.
- Delete comments that only label obvious commands, assignments, or sections in
  very small files.

## Docs And Traceability

- When behavior changes, update the canonical docs section, `docs/registry.json`,
  `docs/traceability.html`, and all files listed in the relevant `code_paths`.
- If research from external sources affects repo rules, log it in `docs/` with
  links in the page's Sources section.
- Do not add a new `D-*` or `F-*` token without adding the matching registry
  entry and traceability row.

## Boundaries

- Do not symlink Omarchy-owned mutable files into this repo.
- Do not edit files under `~/.local/share/omarchy/`; read them only for research.
- Keep machine-specific secrets and host values in gitignored `*.local` files.
- Preserve user changes already present in the working tree.
