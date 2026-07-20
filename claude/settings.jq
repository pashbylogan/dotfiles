# [D-CLAUDE-CONFIG] enforced Claude Code user settings — see docs/decisions.html#D-CLAUDE-CONFIG
# Applied idempotently onto ~/.claude/settings.json by install (apply_jq_deltas);
# only these keys are asserted, so keys Claude Code adds on its own are preserved.
# .env.<KEY> path-assignment auto-vivifies .env and leaves any sibling vars intact.
# Model and effort defaults use .env vars, NOT the top-level `model`/`effortLevel`
# keys: the /model and /effort pickers own/rewrite those keys at runtime (→ drift)
# but never touch .env, so these stay no-ops. CLAUDE_CODE_EFFORT_LEVEL is read from
# the env and is session-only; Claude applies its .env block to the session.
  .theme = "auto"
| .skipAutoPermissionPrompt = true
| .skipWorkflowUsageWarning = true
| .attribution = { "commit": "", "pr": "" }
| .env.ANTHROPIC_MODEL = "opus"
| .env.CLAUDE_CODE_EFFORT_LEVEL = "xhigh"
| .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
| .teammateMode = "auto"
| .statusLine = { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
