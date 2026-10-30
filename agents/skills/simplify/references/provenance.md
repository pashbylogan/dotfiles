# Provenance and compatibility

`SKILL.md` mirrors the `/simplify` prompt that **Claude Code 2.1.314** loads,
copied word for word from the loaded skill text so other agents get the same
review quality. It is not an official Anthropic skill and needs no Claude Code
executable, account, plugin or API at execution time.

## Only deviations from the native prompt

- "via the Agent tool" became "via the host's subagent tool", so it works in
  other harnesses.
- `/code-review` became "a code review"; other hosts don't have that command.
- Claude Code has two versions of the prompt: one with the Agent tool and one
  without. They are merged here. The inline-fallback paragraph and the "state it
  was single-pass" summary line come from the no-Agent-tool version.

Deployment deliberately omits `~/.claude/skills/simplify`: Claude Code already
has the native command, and a personal skill with the same name can override it.

## Sources and updates

- Claude Code skills documentation: <https://code.claude.com/docs/en/skills>
- Reference: the `simplify` command registration in the Claude Code 2.1.314
  binary (two prompt variants, chosen by whether the Agent tool is available)
  and the text it loads when invoked.

Updates are manual: invoke `/simplify` in an explicitly identified Claude Code
release, diff its loaded text against `SKILL.md`, update both files, then run
`make ci`, `make agent-skills` and `make verify-agent-skills`.
