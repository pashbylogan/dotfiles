---
name: t3-subagents
description: Runtime and model routing for subagents launched through T3 Code's orchestration tools (orchestrator_capabilities, target.providerInstanceId). Use inside T3 Code before launching or retrying a subagent.
---

# T3 subagent routing

These rules govern which runtime and model a T3 orchestration call selects. They
do not apply outside T3, and they do not restrict a skill that runs another CLI
directly, such as a cross-model review through `codex exec`.

- Choose the subagent's model deliberately, not automatically the parent's. Account for total tokens, cost, and rework while preserving correctness; free does not mean token-efficient.
- Cheap work goes to OpenCode's strongest free zero-retention model first, not to a small paid OpenAI model: reads, searches, summaries, log digging, and short writers with executable done-criteria. As of 2026-10-25 that is `opencode/deepseek-v4.1-flash-free`; re-check the catalog and, for privacy, the Zen page (https://opencode.ai/docs/zen) when it disappears.
- Never send code, customer data or anything confidential to a free model whose provider retains prompts, logs them or trains on them (on 2026-10-25: Big Pickle, MiMo, Flint, Beam, Nemotron). Those are for public-only text, if anything.
- Escalate to Pi with a strong OpenAI model when the free model fails its check, or from the start for judgment, API shape, hard debugging and anything the parent will not fully verify. Skip the small paid OpenAI tier unless a free model has already failed that kind of task. Other runtimes require an explicit request; never choose the Codex runtime just because a model is OpenAI.
- Consult `orchestrator_capabilities` for live IDs and options; search omitted candidates as needed and reuse discoveries within the task. Match the model to the delegated task using observed reliability, capability, and cost, not price alone.
- Set `target.providerInstanceId` to `pi` or `opencode` and use that runtime's exact catalog model ID. Omit the target only to deliberately inherit both runtime and model. Briefly state the choice and rationale.
- Use supported reasoning options at the lowest sufficient effort; override or clear unsuitable inherited settings. Honor explicit model requests, report unavailability, and disclose material fallbacks; never silently switch runtimes or select paid OpenCode models.
- Catalog presence does not guarantee access through the configured credentials and endpoint. If a child fails with an unsupported-model, access, or configuration error, inspect the full error and verify the provider/model routing before retrying; do not repeat the same launch unchanged. Any fallback must preserve the runtime and model-request constraints above. If no permitted working option is available, report the blocker.
