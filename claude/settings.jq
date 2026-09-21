# [D-CLAUDE-CONFIG] enforced Claude Code user settings — see docs/decisions.html#D-CLAUDE-CONFIG
# .theme selects the theme Quattro generates from the active Omarchy palette and
# writes to ~/.claude/themes/omarchy.json on every `omarchy theme set`. Opting in
# here is what keeps Claude Code themed the same native way as foot, tmux, and
# the browser; install seeds the file via omarchy-theme-set-claude.
# Applied idempotently onto ~/.claude/settings.json by install (apply_jq_deltas);
# only these keys are asserted, so keys Claude Code adds on its own are preserved.
# .env.<KEY> path-assignment auto-vivifies .env and leaves any sibling vars intact.
# Model and effort defaults use .env vars, NOT the top-level `model`/`effortLevel`
# keys: the /model and /effort pickers own/rewrite those keys at runtime (→ drift)
# but never touch .env, so these stay no-ops. CLAUDE_CODE_EFFORT_LEVEL is read from
# the env and is session-only; Claude applies its .env block to the session.
# `skipAutoPermissionPrompt` is absent for the same reason — an upstream migration
# deletes it (→ drift); `skipWorkflowUsageWarning` is the same shape, no migration yet.
# The feedback keys mute Anthropic's draft/survey prompts. /config owns the
# feedbackDrafts row but only rewrites it when the user picks a value, so no drift.
  .theme = "custom:omarchy"
| .skipWorkflowUsageWarning = true
| .attribution = { "commit": "", "pr": "" }
| .env.ANTHROPIC_MODEL = "opus"
| .env.CLAUDE_CODE_EFFORT_LEVEL = "xhigh"
| .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
| .teammateMode = "auto"
| .statusLine = { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
| .feedbackDrafts = "off"
| .feedbackSurveyRate = 0
