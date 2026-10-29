---
name: t3-subagents
description: Runtime and model routing for subagents launched through T3 Code's orchestration tools (orchestrator_capabilities, target.providerInstanceId). Use inside T3 Code before launching or retrying a subagent.
---

# T3 subagent routing

These rules govern which runtime and model a T3 orchestration call selects. They
do not apply outside T3, and they do not restrict a skill that runs another CLI
directly, such as a cross-model review through `codex exec`. [D-AGENT-SKILLS]

## Choose a route

- Honor explicit model/runtime requests, privacy constraints and approval gates before applying defaults. Never send code, customer data or anything confidential to a free endpoint that retains, logs or trains on prompts; consult `references/free-models.md`.
- Read `references/model-routing.md` for the current task defaults. Choose deliberately rather than automatically inheriting the parent. Route by ambiguity, consequence of failure and strength of the completion check, not just labels such as research, writing or review.
- Use the bounded-worker route for narrow searches, extraction, summaries and log triage whose outputs the parent can cheaply verify. Use the standard-implementer route for scoped implementation, tests and straightforward debugging with clear acceptance criteria.
- Start on the deep-reasoner route for architecture, API design, hard debugging, conflicting evidence, consequential judgment or work the parent cannot fully verify. Do not require a failed cheap attempt first.
- Delegate independent review only when risk warrants it. A reviewer role does not itself select a model. Use the visual specialist only when the selected runtime exposes the required tools; a capable model does not supply missing tools.
- Optimize for successful completion, elapsed time, total cost and parent rework, not token price alone. A suitable paid Pi worker need not wait for a free model to fail. Other runtimes require an explicit request; never choose Codex merely because a model is OpenAI, or silently select paid OpenCode models.

## Launch and escalate

- Consult `orchestrator_capabilities` for live IDs and options; search omitted candidates as needed and reuse discoveries within the task. This skill supplies policy, not a catalog or a replacement for T3's launch, permission, isolation or lifecycle mechanisms.
- Set `target.providerInstanceId` to `pi` or `opencode` and use that runtime's exact catalog model ID. Omit the target only to deliberately inherit both runtime and model. Briefly state the choice and rationale.
- Use supported reasoning options at the lowest sufficient effort; override or clear unsuitable inherited settings. Reference defaults are starting points, not permission to send unsupported options.
- Give the child a bounded objective and completion checks. Verify its result before accepting it. After a substantive failure, allow at most one escalation to the deep-reasoner route with the failed check and relevant evidence; do not loop through cheap retries. If that fails, report the blocker or reconsider the task rather than launching another automatic attempt.
- Catalog presence does not guarantee access through configured credentials and endpoints. On an unsupported-model, access or configuration error, inspect the full error and verify routing before retrying; never repeat the same launch unchanged. This is not evidence of task-quality failure. Honor explicit requests, report unavailability and disclose material fallbacks; if no permitted working option exists, report the blocker.
