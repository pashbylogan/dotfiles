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

# T3 Code only

Apply these defaults only inside T3 Code, not standalone harness sessions. Preserve explicit user requests, approval gates, runtime/model constraints, and resource safety.

- Put non-project scratch scripts, reports, downloads and build outputs in a private task directory under `/tmp` (`mktemp -d /tmp/t3-task-XXXXXX`), even when T3 starts in persistent scratch. Keep project work and requested durable deliverables in their designated locations; do not relocate T3 state or active worktrees. Clean only your own disposable files; identify retained `/tmp` outputs as temporary.
- Work directly by default. Delegate bounded independent work only when parallelism, context isolation or independent judgment justifies startup and integration. Many files or long logs alone are not a reason. Prefer one coordinator directly supervising workers, not dispatch-only relay layers.
- Keep reads and tool output targeted; reuse still-applicable evidence and reference artifacts rather than repeatedly copying full logs, briefs or policy packets. Do not economize by skipping necessary understanding or verification.
- Batch related updates. Send assignments, decisions, actionable blockers, material changes, safety events and completion—not acknowledgment-only replies or unchanged status reminders. Preserve required lease renewals and explicitly requested heartbeats.
- Use completion notifications; check status only when needed mid-turn. Scope locks to the actual shared operation/resource so runtime waits do not block unrelated isolated edits or CPU-only checks.
- Review small changes inline, including cleanup lenses; avoid automatic per-lens agent fan-out. Use independent review when risk or an explicit request warrants it. Recheck changed risks after fixes, not another broad planning/review cycle; stop when acceptance criteria are met.
