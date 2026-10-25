# Provenance and compatibility

This skill is a locally authored behavioral reimplementation, not an official
Anthropic skill, a verbatim prompt export, or a promise of identical model output.
It requires no Claude Code executable, account, plugin or API at execution time.

Reference inspected: installed **Claude Code 2.1.310**, whose bundled command
registration and prompt templates were inspected read-only. Its simplify flow is:

1. Gather the target diff, including working-tree changes where relevant.
2. Run four independent cleanup reviewers concurrently: reuse, simplification,
   efficiency, and altitude (root-cause depth).
3. Merge duplicate findings, apply appropriate behavior-preserving fixes, and
   summarize fixes/skips. It is quality cleanup, not correctness bug hunting.
4. When its agent tool is unavailable, cover all four angles inline and disclose
   the fallback.

Older descriptions of `/simplify` often mention three reviewers. This skill
tracks the four-angle behavior observed in 2.1.310, not that older formulation.
No proprietary implementation or full original prompt is bundled here.

## Deliberate portability adaptations

- Uses the current harness's permitted subagent tools, models and approvals.
  It never assumes a Claude-only Agent tool or starts top-level conversations.
- Handles missing or partially failed subagent support without false fan-out
  claims; the parent can cover missing angles inline.
- Reviewers are read-only; the parent verifies findings and owns all edits.
- Accounts for untracked files, empty/unborn repositories, explicit targets,
  user changes, project instructions, tests and side-effect boundaries.
- Deployment deliberately omits `~/.claude/skills/simplify`: Claude Code already
  has the native command, and installing a personal skill with the same name can
  override it or alter invocation/commit behavior. Other configured roots receive
  managed copies. Existing user-owned simplify skills are not overwritten.

## Sources and updates

- Claude Code skills documentation:
  <https://code.claude.com/docs/en/skills>
  (skills, invocation and personal-skill behavior; includes the special
  pre-commit handling of user-provided `simplify`/`verify` skills).
- Local reference executable: `~/.local/share/claude/versions/2.1.310`.

Updates are manual: inspect an explicitly identified Claude Code release,
compare its review angles and orchestration, revise this skill and provenance
in dotfiles together, then run `make ci`, `make agent-skills` and
`make verify-agent-skills`. Do not scrape a moving binary automatically at
install time. Deployment copies remain independent of the reference executable.
