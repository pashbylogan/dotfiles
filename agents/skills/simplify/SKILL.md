---
name: simplify
description: Review changed code for reuse, simplification, efficiency, and root-cause depth, then apply behavior-preserving cleanups. Use when the user asks for /simplify, to simplify recent changes, or for Claude Code's cleanup flow in another agent. Accept an optional file, branch, PR, or focus.
---

# Simplify

A portable, locally authored counterpart of Claude Code's `/simplify` workflow.
Improve the quality of changed code and apply the worthwhile fixes. This is a
cleanup pass, **not a correctness/security bug hunt or a feature redesign**.
Follow the project's agent guidance and preserve intended behavior.

## 1. Establish the review scope

- Respect the user's target and focus: a file/directory, branch, commit range,
  pull request, or a concern such as memory use. Resolve it with the host's
  available tools; do not interpolate an untrusted target into a shell command.
- Inspect repository status before editing. Normally compare the current branch
  with its upstream using a three-dot diff. If there is no upstream, use the
  actual main branch when available, otherwise the previous commit. Do not fetch,
  switch branches, or change the index just to gather review context.
- Include staged and unstaged changes when present (or when the branch diff is
  empty); `git diff HEAD` captures both against HEAD. Inspect relevant untracked
  source files separately: Git diffs do not include them. Handle a new repository
  without a HEAD by reading its in-scope files directly.
- Inspect the full in-scope diff and the surrounding functions. For a supplied
  target, limit the review to that target rather than sweeping unrelated work.
  Do not silently truncate a large diff; partition it into explicit review units.
- State the chosen scope. If no changes or target can be identified, ask for a
  target rather than expanding into an unsolicited whole-repository refactor.

## 2. Review from four independent angles

When permitted subagent tools are available, launch **four read-only reviewers
concurrently**, one per angle below. Use the current harness's supported
subagent mechanism and follow its model-selection, approval, and delegation
rules. Do not assume Claude's tool names, hard-code model IDs, start top-level
conversations, or launch nested reviewers from the children.

Give each reviewer a self-contained brief with the goal, exact scope/diff (or a
shared readable artifact), relevant file paths, applicable project guidance, its
assigned angle, and the finding format below. Let it inspect supporting code,
but **do not let reviewers edit files**. The parent owns the fixes.

If subagents are unavailable, prohibited, or a launch fails, complete the missing
angles yourself in this context. Do not retry unsupported tools repeatedly or
pretend an inline pass was an independent review. Clearly disclose inline or
mixed-mode execution in the final summary.

### A. Reuse

Look for newly written logic that duplicates an existing capability. Search
nearby code, shared utilities, and relevant callers before proposing a new
helper. Identify the existing function/module that should be reused and the
specific duplicated decision it would remove. Avoid speculative abstractions
that merely make two superficially similar snippets look alike.

### B. Simplification

Look for state that can be derived instead of stored, redundant branches,
near-duplicate implementations, excessive nesting, unnecessary wrappers, and
obsolete code left by the change. Propose the smaller equivalent structure.
Do not trade clear local code for indirection or perform cosmetic churn.

### C. Efficiency

Look for repeated computation, redundant I/O or lookups, avoidable allocation,
and newly serialized independent work. Pay particular attention to startup and
hot paths. Inspect long-lived closures/objects for unnecessarily retained data;
when retention is real, prefer storing only needed fields. Name the cheaper
alternative and why it matters. Preserve ordering, concurrency limits, failure
semantics and resource ownership; do not invent unmeasured performance claims.

### D. Altitude (root-cause depth)

Look for a workaround applied at the wrong layer: special cases, repeated guards,
or exceptions compensating for a shared mechanism. Identify a simpler fix at
the layer that owns the decision. Keep it bounded: do not turn a cleanup review
into a broad architectural rewrite or change requirements to make code simpler.

### Reviewer output

Return only actionable findings (an empty list is valid), each containing:

- `file` and `line` locating the current code;
- `summary`: a one-sentence cleanup opportunity;
- `cost`: what is duplicated, wasted, retained, or harder to maintain;
- `fix`: the concrete behavior-preserving alternative, including the existing
  helper when suggesting reuse.

Do not pad the report with style preferences or general advice. Out-of-scope
correctness concerns may be mentioned separately, but are not cleanup findings
and do not authorize behavior changes.

## 3. Apply the worthwhile fixes

1. Wait for every reviewer that actually started; handle failures explicitly.
   Deduplicate findings about the same location or underlying mechanism.
2. Inspect each finding against the code yourself. Apply small, clear fixes
   directly; the user requested improvements, not just a report.
3. Skip false positives, speculative optimizations, behavior changes, and fixes
   requiring substantial changes outside the reviewed scope. Record a short
   reason for each meaningful skip rather than arguing with the reviewer or
   starting ritual review rounds.
4. Preserve existing user edits and unrelated changes. Do not discard work,
   install dependencies, commit, push, or perform destructive cleanup implicitly.
5. Run relevant tests and the repository's prescribed checks. If a command is
   expensive or has external side effects, follow the existing permission rules.
   Inspect the final diff for scope and behavior preservation. State failed,
   unavailable, or unrun checks honestly. If a small fix fails verification,
   repair or undo only your own edit; do not hide the failure.

## 4. Finish concisely

Report the reviewed scope, actual review mode (four parallel agents, inline, or
mixed), fixes applied, meaningful skips, and verification results. If nothing
needed changing, say so. Never claim parallel review or passing tests that did
not occur.

For provenance, version drift, and portability differences, read
`references/provenance.md` beside this skill when needed.
