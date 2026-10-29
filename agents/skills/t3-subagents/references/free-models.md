# Free OpenCode endpoint privacy, as of 2026-10-29

Re-check the catalog (`opencode models`) and the privacy notes on https://opencode.ai/docs/zen before relying on this.

Endpoint eligibility only, not a quality ranking. Task defaults and escalation
choices live in `model-routing.md`. [D-AGENT-SKILLS]

- Zero-retention, not used for training: DeepSeek V4.1 Flash Free (`opencode/deepseek-v4.1-flash-free`) and GLM-5.3-Flash Free.
- Retain, log or train on prompts, so never for code or customer data: Big Pickle, MiMo, Flint, Beam, Nemotron.
