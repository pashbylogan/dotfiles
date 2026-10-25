---
name: ub-tools
description: Run Uncle Bob's crapper (CRAP score), dryer (structural duplication) and mutator (mutation testing) CLIs. Use for ub-mode quality checks, or when asked to find complex under-tested functions, duplicate code, or surviving mutants.
---

# ub-tools

Pinned CLIs installed at `~/.local/bin/{crapper,dryer,mutator}`. Before running
one, read its usage notes: they cover side effects, cost and how to read results.

| Tool | Measures | ub-mode gate | Notes |
|---|---|---|---|
| crapper | Complexity weighted by coverage | CRAP strictly below 10 per function | `references/crapper/usage.md` |
| dryer | Structural duplication | Similarity below 0.8 | `references/dryer/usage.md` |
| mutator | Mutants that tests fail to kill | No survivors, no uncovered sites | `references/mutator/usage.md` |

Each tool's upstream README and license sit beside its usage notes.

Maintenance: the `agents/` directory in your dotfiles checkout (see its README).
