# Subagent execution

These rules apply when a subagent is used; they do not request delegation or define when to delegate.

Inside T3 Code, when its orchestration tools are available, load the `t3-subagents` skill before launching a subagent. Elsewhere, use the host's delegation mechanism, preserve explicit model/runtime requests, and report missing capabilities rather than inventing tool support.

## Skill precedence

- When `ub-mode` is loaded, its rules (test first, the ub-tools gates) override ponytail's minimal-testing guidance. Otherwise ponytail is the default.

## Handoffs and results

- Give each child a self-contained objective, relevant paths/context, scope and edit ownership, constraints, completion checks, and desired output. Do not copy full histories or assume shared conversational knowledge. If children run in parallel, keep their tasks independent and isolate overlapping edits.
- Request concise findings with file/line or source references, verification evidence, and unresolved risks. Use progressive disclosure: start with summaries/indexes, load only task-relevant details, and keep bulky results in artifacts referenced by path.
- The parent integrates and verifies returned work against acceptance criteria using tests and targeted checks. A child's report is not proof of correctness. Stop once criteria are met; avoid duplicate investigation and ritual review rounds.

## Instruction hygiene

- Keep AGENTS.md short, actionable, and durable. Include non-obvious preferences and recurring gotchas, not generic advice, volatile model lists, or tutorials. Keep project-specific commands near the project; link detailed guidance for on-demand reading. Prune or revise rules based on observed failures.
