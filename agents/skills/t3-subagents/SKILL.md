---
name: t3-subagents
description: Runtime and model routing for subagents launched through T3 Code's orchestration tools (orchestrator_capabilities, target.providerInstanceId). Use inside T3 Code before launching or retrying a subagent.
---

# T3 subagent routing

These rules govern which runtime and model a T3 orchestration call selects. They
do not apply outside T3, and they do not restrict a skill that runs another CLI
directly, such as a cross-model review through `codex exec`.

- Choose the subagent's model deliberately, not automatically the parent's. Account for total tokens, cost, and rework while preserving correctness; free does not mean token-efficient.
- Default to Pi for GPT/OpenAI models. Free OpenCode models through OpenCode are also allowed without asking. Other runtimes require an explicit request; never choose the Codex runtime just because a model is OpenAI.
- Consult `orchestrator_capabilities` for live IDs and options; search omitted candidates as needed and reuse discoveries within the task. Match the model to the delegated task using observed reliability, capability, and cost, not price alone.
- Set `target.providerInstanceId` to `pi` or `opencode` and use that runtime's exact catalog model ID. Omit the target only to deliberately inherit both runtime and model. Briefly state the choice and rationale.
- Use supported reasoning options at the lowest sufficient effort; override or clear unsuitable inherited settings. Honor explicit model requests, report unavailability, and disclose material fallbacks; never silently switch runtimes or select paid OpenCode models.
- Catalog presence does not guarantee access through the configured credentials and endpoint. If a child fails with an unsupported-model, access, or configuration error, inspect the full error and verify the provider/model routing before retrying; do not repeat the same launch unchanged. Any fallback must preserve the runtime and model-request constraints above. If no permitted working option is available, report the blocker.
