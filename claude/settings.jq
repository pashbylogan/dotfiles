# [D-CLAUDE-CONFIG] enforced Claude Code user settings — see docs/decisions.html#D-CLAUDE-CONFIG
# Applied idempotently onto ~/.claude/settings.json by install (apply_jq_deltas);
# only these keys are asserted, so keys Claude Code adds on its own are preserved.
# .env.<KEY> path-assignment auto-vivifies .env and leaves any sibling vars intact.
  .model = "opus"
| .effortLevel = "xhigh"
| .theme = "auto"
| .skipAutoPermissionPrompt = true
| .skipWorkflowUsageWarning = true
| .attribution = { "commit": "", "pr": "" }
| .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
| .teammateMode = "auto"
| .statusLine = { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
