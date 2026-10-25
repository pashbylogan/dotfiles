# Subagent execution

These rules apply when a subagent is used; they do not request delegation or define when to delegate.

The runtime-routing rules below apply inside T3 Code when its orchestration tools
are available. Outside T3, use the host's available delegation mechanism, preserve
explicit model/runtime requests, and report missing capabilities rather than
inventing tool support.

## Runtime and model selection

- Choose the subagent's model deliberately, not automatically the parent's. Account for total tokens, cost, and rework while preserving correctness; free does not mean token-efficient.
- Default to Pi for GPT/OpenAI models. Free OpenCode models through OpenCode are also allowed without asking. Other runtimes require an explicit request; never choose the Codex runtime just because a model is OpenAI.
- Consult `orchestrator_capabilities` for live IDs and options; search omitted candidates as needed and reuse discoveries within the task. Match the model to the delegated task using observed reliability, capability, and cost, not price alone.
- Set `target.providerInstanceId` to `pi` or `opencode` and use that runtime's exact catalog model ID. Omit the target only to deliberately inherit both runtime and model. Briefly state the choice and rationale.
- Use supported reasoning options at the lowest sufficient effort; override or clear unsuitable inherited settings. Honor explicit model requests, report unavailability, and disclose material fallbacks; never silently switch runtimes or select paid OpenCode models.
- Catalog presence does not guarantee access through the configured credentials and endpoint. If a child fails with an unsupported-model, access, or configuration error, inspect the full error and verify the provider/model routing before retrying; do not repeat the same launch unchanged. Any fallback must preserve the runtime and model-request constraints above. If no permitted working option is available, report the blocker.

## Handoffs and results

- Give each child a self-contained objective, relevant paths/context, scope and edit ownership, constraints, completion checks, and desired output. Do not copy full histories or assume shared conversational knowledge. If children run in parallel, keep their tasks independent and isolate overlapping edits.
- Request concise findings with file/line or source references, verification evidence, and unresolved risks. Use progressive disclosure: start with summaries/indexes, load only task-relevant details, and keep bulky results in artifacts referenced by path.
- The parent integrates and verifies returned work against acceptance criteria using tests and targeted checks. A child's report is not proof of correctness. Stop once criteria are met; avoid duplicate investigation and ritual review rounds.

## Instruction hygiene

- Keep AGENTS.md short, actionable, and durable. Include non-obvious preferences and recurring gotchas, not generic advice, volatile model lists, or tutorials. Keep project-specific commands near the project; link detailed guidance for on-demand reading. Prune or revise rules based on observed failures.
