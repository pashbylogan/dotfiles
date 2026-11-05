# Examples and templates

## Pairwise judge prompt template (bucket B)

Send to each judge, fresh context, read-only. Run twice per judge with A/B swapped; a win counts only if it survives both orders.

```
You are comparing two versions of <artifact type>: VERSION A and VERSION B.
You also see REFERENCE examples of strong work in this category.

For each category below, decide which version is better, or "tie" if the
difference is negligible. Ignore length and surface polish unless they serve
the category. Reason first, then give the verdict.

Categories:
- <category 1>: <what it means>
- <category 2>: ...

Return JSON:
{"per_category": {"<cat>": {"reasoning": "...", "winner": "A"|"B"|"tie"}},
 "biggest_problem_in_loser": "...",
 "blockers_in_either": [...]}
```

Never include the target, prior verdicts, which version is the candidate, or the agent's reasoning.

Optional progress report (not used for keep/revert): a separate pointwise 1–10 call per category against the references.

## Example A — programmatic (tool-description trimming)

Objective: "Our agent tool descriptions are bloated; shrink them without making models misuse the tools."
- Bucket A. Phase 0: collect every historical misuse case, categorize, turn each into an eval case (~85 cases).
- Gates: none beyond the eval itself.
- Phase 1 primary: cases passed (maximize) → target: all pass, commit.
- Phase 2 primary: total description tokens (minimize) subject to gate "all cases still pass"; target ≤ 1/3 of original.
- Data tiers: ~60% dev (full diagnostics), ~20% selection (aggregate only), ~20% held-out test (run once at end). Add 1–2 tripwire cases whose expected tool call contradicts the spec.
- Gaming risks: deleting hard cases; descriptions that name eval cases verbatim. Forbid both.
- Expect mid-climb dips (score drops after a change) — that's the eval catching regressions, revert and continue.

## Example B — judge council (UI redesign)

Objective: "Make the app's UI genuinely good."
- Bucket B. Artifact: frontend styles/components. Gate: existing UI tests + no broken screens in a screenshot sweep of N real states.
- Council: 3 model families (none the editor's), pairwise candidate-vs-incumbent with order swap. Categories = hierarchy, color & contrast, typography, density, affordances, consistency. References = screenshots of 2 best-in-class competitors.
- Target: candidate beats both competitor references in every category for 2 consecutive rounds. Greedy W=6, then 2 branches (e.g. one restructures layout, one restyles within current layout). Human check at first target hit.
- Known risks: judge drift (re-score baseline every 10 rounds), aesthetic collapse toward safe/gray (human checkpoint catches it), inflation if target leaks.

## Example C — not climbable as stated

Objective: "Grow newsletter revenue."
- Bucket C: signal lags weeks and is confounded.
- Decompose into climbable proxies, each with what it loses:
  - Subject-line open-rate predictor scored against your own historical opens (loses: causal effect on revenue).
  - Landing-page conversion on a fixed set of judge personas (loses: real user behavior).
- State plainly: these climbs optimize proxies; revenue still needs a real experiment.
