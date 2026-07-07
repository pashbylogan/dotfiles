# [D-CLAUDE-CONFIG] enforced Claude Code user settings — see docs/decisions.html#D-CLAUDE-CONFIG
# Applied idempotently onto ~/.claude/settings.json by install (apply_jq_deltas);
# only these keys are asserted, so keys Claude Code adds on its own are preserved.
# .env.<KEY> path-assignment auto-vivifies .env and leaves any sibling vars intact.
# Model default uses .env.ANTHROPIC_MODEL, NOT the top-level `model` key: the
# /model picker owns/rewrites `model` (Default clears it → drift) but never touches
# .env, so this stays a no-op. Claude applies its env block to the session.
  .effortLevel = "xhigh"
| .theme = "auto"
| .skipAutoPermissionPrompt = true
| .skipWorkflowUsageWarning = true
| .attribution = { "commit": "", "pr": "" }
| .env.ANTHROPIC_MODEL = "opus"
| .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
| .teammateMode = "auto"
| .statusLine = { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
