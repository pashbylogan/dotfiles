# T3 task defaults

Policy defaults, last reviewed 2026-10-29. These labels are guidance, not T3 agent
types or native model aliases. Change model choices here rather than scattering
IDs through instructions. Discover exact IDs, access and supported options with
T3 before launching; this file is not a catalog snapshot. [D-AGENT-SKILLS]

## Current choices

Use these defaults only after delegation or a retry has been chosen under the
shared instructions. Apply the target-selection rules in `../SKILL.md`.

| Route | Typical task | Runtime / model | Effort starting point | Status / constraints |
| --- | --- | --- | --- | --- |
| Bounded worker | Narrow search, extraction, checkable summary, log triage | `opencode` / `opencode/deepseek-v4.1-flash-free` | No explicit reasoning override; clear incompatible inherited options | Existing default; not locally benchmarked. See `free-models.md` for privacy eligibility. |
| Standard implementer | Scoped change, tests, straightforward debugging with acceptance checks | `pi` / `openai/gpt-6.1-terra` | Lowest sufficient supported effort, starting at `low` if available | Candidate default; not locally validated. |
| Deep reasoner | Architecture, API shape, hard debugging, conflicting evidence, unverified or high-consequence judgment | `pi` / `openai/gpt-6.1-sol` | `medium` if supported; raise to `high` when depth warrants it | Strong-model baseline, not a measured winner. |
| Independent reviewer | Correctness or design review | Deep-reasoner selection above | Same as deep reasoner | Consider a different capable model only with evidence of useful independent judgment and within runtime/request constraints. |
| Visual specialist | Screenshot reasoning or computer-use tasks | Standard-implementer selection above, only with required runtime tools | Lowest sufficient supported effort | Deep reasoner only if it supports the needed modality/tools; otherwise report the limitation. Candidate, not locally validated. |

Explicit user choices and privacy/runtime constraints override this table. If a
candidate is unavailable, disclose the issue and use the deep-reasoner baseline
only when permitted; never silently change a requested model or runtime. Avoid
falling back to a cheaper model merely because it is listed.

## Promote or replace a model

1. Verify live availability, credential access, endpoint privacy and runtime/tool
   support. A model release or catalog listing alone is not validation.
2. Mark the replacement as a candidate for specific routes. Keep the incumbent
   selection in the comparison notes or git history for rollback.
3. Compare candidate and incumbent on a small fixed set of representative tasks:
   checkable extraction, scoped implementation/tests, hard debugging/design and
   visual work only where relevant. Keep prompts, harness/tools, checks and
   effort settings consistent enough to distinguish model effects; repeat noisy
   cases. Include a fixed strong-model baseline.
4. Record completion-check success, elapsed time, retries/escalations, parent
   repair work and total cost where available. Include failed attempts and
   escalation costs, not just the successful child's tokens. Inspect artifacts
   and failed transcripts; a child's claim of success is not a passing check.
5. Promote only routes that improve the success/cost/latency tradeoff without
   unacceptable quality regressions. Record date, task set, settings, results
   and remaining risks here or in a linked durable report. Roll back regressions.

This maintenance checklist does not trigger delegation or evaluation runs.
Keep routing as guidance rather than a router service, private catalog or
duplicate T3 presets. Revisit this boundary if shipped T3 task-aware defaults
supersede the policy.

## Evidence and limits

- [T3 orchestration documentation](https://github.com/pingdotgg/t3code/blob/main/docs/orchestration-v2/orchestrator-mcp-server.md): native delegation and explicit targets. The exposed role field is not a documented task-aware model router. The proposed [named-agent/tier PR #18225](https://github.com/pingdotgg/t3code/pull/18225) was closed without merging when checked; do not configure against a proposal.
- [LLMRouterBench](https://arxiv.org/abs/2601.07206): curated ensembles and simple baselines can compete with complex routing. This is general routing evidence, not a benchmark of these agent defaults.
- [Anthropic's agent evaluation guidance](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents): evaluate model plus harness, actual outcomes, latency, cost and errors.
- [OpenAI's Terra announcement](https://openai.com/index/introducing-gpt-6-1-terra/): vendor evidence for efficient coding, visual reasoning, computer use and writing; not local proof that Terra beats the incumbent. Terra is a candidate standard worker, not a universal replacement for deep reasoning.
