# PR review comments

Verbatim typed messages, chosen for register range. Slack mentions and links are rendered as displayed. Ids are from stylometrics.py --dump.

### Hedged suggestion
2026-03-30, https://github.com/cypris-ai/frontend/pull/6362#discussion_r3010720058

> Would probably want to switch this to an npm package if we were going to deploy to prod

### Question about intent
2026-03-16, https://github.com/cypris-ai/data/pull/304#discussion_r2943181450

> It probably depends what the intention is of `application_ucids`, because if we're going to show it in the UI we wouldn't want all the permutations. When would we search this field vs `id_fuzz`?

### Leaving the call to the author
2026-01-22, https://github.com/cypris-ai/devops/pull/72#discussion_r2718449750

> We use asyncpg in the backend repo, probably better to have consistency across the codebase but up to you

### Disagreeing by asking why
2026-09-14, https://github.com/cypris-ai/developer-tooling/pull/4#discussion_r4007691549

> Why have a new MCP server rather than sticking these files into cypris-dev-mcp and growing its capabilities? And then we only have to have one running locally when developing.

### Reply on his own PR
2026-04-06, https://github.com/cypris-ai/data/pull/336#discussion_r3041436257

> fixed the index

## Before and after

Before (not his: model-style rewrite written for contrast):

> Consider consolidating these imports at the top of the file. Importing pytest both here and inside the function above is redundant and could confuse readers.

After (his, verbatim):

> You import pytest here and in a function above, consider importing at the top of the file? (data#293)
