# Prompts to coding agents

Verbatim typed messages, chosen for register range. Slack mentions and links are rendered as displayed. Ids are from stylometrics.py --dump.

### Statement question
2026-09-16, A575, 856996dd-7b3f-4c66-9825-de9ee99a6813.jsonl

> You're saying it only affected two cases?

### Instruction with a disagreement clause
2026-09-15, A551, 856996dd-7b3f-4c66-9825-de9ee99a6813.jsonl

> Now check the copilot comments on both prs. If you disagree, say so. Otherwise fix.

### Pushing back
2026-09-30, A1109, fd84be81-9006-41f8-976f-21764f16f577.jsonl

> I really feel like we don't need all these tables and DAGs. Is there a way to simplify?

### Casual aside
2026-09-17, A645, 8b8adf55-47f9-4969-b940-97493a2a3453.jsonl

> well I'm just saying, our local claude alias already does this kind of thing. I don't want you to have to manage this process you know? It should be built-in to how I use claude?

### Paragraph brief
2026-09-29, A1043, d8d2412d-9dee-40d9-9a21-537679b72292.jsonl

> I'm feeling pretty confident that #6410 could be implemented simpler. I like how we organized the repository files in IWS so that all the logic could be isolated and the sql queries could be in one place. This is another layer on top of data, so I'd like to try to create a similar interface between it and the rest of the codebase if possible. Feel free to launch subagents to investigate different paths of making it simpler
