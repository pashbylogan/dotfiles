---
name: hill-climb
description: Turn a fuzzy objective into a "hill climb" (Theo Browne's framing of the classic search method) — a scorer that emits a number plus per-case diagnostics, a defined top, a search strategy, and a ready-to-run loop prompt an agent (Claude Code, Codex, /goal) can execute autonomously until the score stops rising. Use this whenever the user wants to set up a hill climb, an eval-driven agent loop, autoresearch-style iteration, "make this number go up", "iterate until it's a 9/10", a /goal prompt, a judge/council scoring loop, or wants an agent to grind on an objective for hours without supervision — even if they don't say "hill climb".
---

# Hill Climb

A hill climb = **objective → scorer (number + diagnostics) → search loop (change, score, keep or revert, branch when stuck) → stop at a defined top.**
Agents reliably push any score up. The hard parts are (1) a score that can't rise unless the objective actually improves, (2) a search that doesn't stall on a local maximum, (3) knowing where the top is. Spend most effort on (1).

Deliverable: two copy-paste blocks in the response, the climber-facing spec + agent prompt (`HILL_CLIMB.md` content) and the private scorer notes (`SCORER_PRIVATE.md` content), plus a scorer scaffold when the score is programmatic. See Delivery below. This skill designs the climb; a separate, fresh agent session runs it (Step 6). Never start climbing in the session that designed the scorer. Evidence behind each rule is in `references/research.md`; read it when the user asks why, or when a design choice is contested.

## Step 1 — Classify the objective (be blunt)

Exactly one bucket; say which:

- **A. Programmatically scorable.** A script can measure it (tests, latency, size, tokens, eval pass rate, loss). Always try to push the objective here first, even if it means building an eval set (e.g. collect every historical failure, one test case each).
- **B. Judge-scorable.** Only taste can measure it (UI, copy, design). Use a judge council (Step 2b). Strictly weaker than A; say so.
- **C. Not climbable as stated.** No signal, or signal lags weeks. Decompose into measurable proxies and state what each proxy loses. If no honest proxy exists, say so and stop.

Then run the readiness gate (Step 1.5) before designing anything.

## Step 1.5 — Readiness gate and interrogation

Do not write `HILL_CLIMB.md` until every check passes. A vague objective produces a climb that optimizes the wrong thing, and the agent will climb it confidently for hours.

**The gate:**
1. **Artifact** — the thing being changed is named and bounded (paths, files, document, page).
2. **Signal** — a score can be produced each round without the user present (script, or council in bucket B).
3. **Validity** — the user agrees: "if this score hit the target and nothing else changed, I'd be satisfied."
4. **Exploit check** — the cheapest way to max the score without doing the real work has been named and blocked by a gate or forbidden move.
5. **Examples** — at least 3 concrete good and 3 bad examples exist (or a handful of eval cases), so "good" isn't abstract.
6. **Guardrails** — what must not get worse is listed.
7. **Top and budget** — target, budget cap, and rough cost per evaluation are known.

Fill in what you can infer from context first. Interrogate only on checks that still fail.

**How to interrogate:**
- **Propose, then ask.** Never open with "what's your metric?"; most people can't answer that well. Offer 2–3 concrete candidate scorers with one-line tradeoffs and ask which is closest, or what's wrong with all of them. People critique far better than they specify. Use a tappable-options tool if available.
- **Grade to define.** When criteria are fuzzy, draft or collect 4–6 example outputs and have the user grade them good/bad with a one-line reason. Their reasons become the rubric. Criteria usually only become clear while looking at concrete outputs.
- **Ask the hacker's question** for check 4: "How would a lazy agent hit the target without doing what you actually want?" If the user can't answer, propose 2–3 exploits yourself and ask which ones would matter.
- **At most 3 questions per turn**, each tied to a failing check. Say which check it's for.
- **Push back on bad answers.** If the user proposes a metric that is easy to game, lags weeks, or only loosely tracks the objective, say so directly and propose a better one.
- **Cap it.** After 3 interrogation rounds with checks still failing, reclassify: bucket C with an honest proxy, or "not a hill climb; here's why." Don't loop forever.
- **"Just go" override.** If the user declines to answer, proceed, but list every assumption under a `## Assumptions (unconfirmed)` section in the spec and add a mandatory human checkpoint after round 3.

**Expect criteria to move after the climb starts.** The rubric/eval is versioned (`rubric-v1`, `v2`…). Schedule a short user review of the first few accepted changes; if the user's criteria shift, update the scorer, bump the version, and re-measure the baseline under the new version. Never compare scores across versions.

## Step 2a — Programmatic scorer

- **Output = scalar + diagnostics.** The scorer prints JSON: `{"gates_passed", "primary", "secondary", "per_case": [{id, pass/score, error, notes}]}`. A bare number tells the agent *that* it failed, not *why*; per-case failure detail is what makes the next change good.
- **Lexicographic**: gates (must pass, else fail) → primary → optional secondary. Gates encode everything that must not regress. Soft constraints (cost, size) can be a penalty multiplier instead of a hard fail.
- **Baseline first**, run N times; record mean and spread. Gains below the spread are noise.
- **Three data tiers**: dev (agent sees per-case diagnostics), selection (agent sees only aggregate; used for keep/revert), and a final held-out test run once at the end. Large dev-vs-test gap = overfitting.
- **Sandbox the scorer.** Agent can read but not write scorer, tests, rubric, or fixtures (read-only mount, separate repo, or checksum verified every round). The scorer must not expose internals the artifact could read (ground truth, future data, simulator state). Agents with tool access find these shortcuts.
- **Tripwire cases**: add 1–2 cases that are impossible to pass legitimately (expected output contradicts the spec). If one ever passes, the agent is gaming the scorer; halt and flag.

## Step 2b — Judge council (bucket B only)

- **Pairwise, not absolute.** Each round, judges compare CANDIDATE vs INCUMBENT (plus reference examples) and answer which is better per category, with "tie" allowed. Relative judgment is more stable than 1–10 scales and maps directly onto keep/revert.
- **Swap order and require agreement.** Run each comparison in both orders; a win counts only if it survives both, otherwise tie.
- **≥3 judges from different model families**, none from the family doing the editing (self-preference bias is real and shared within a family).
- **Accept a change only if no judge prefers the incumbent and at least a majority prefer the candidate.**
- **Fixed rubric**, 4–6 named categories with anchors; reasoning before verdict; explicit instruction to ignore length/polish as such (verbosity bias).
- **Hide targets and history** from judges; fresh context each call.
- **Pointwise 1–10 scores are for reporting progress only**, never for keep/revert. Re-score a frozen baseline every ~10 rounds to detect scale drift.
- **Calibrate once**: hand-judge ~10 pairs yourself; if the council disagrees with you on more than ~2, fix the rubric before climbing.
- **Human checkpoint** after the first ~3 accepted rounds (catches criteria drift early), at first target hit, and every ~10 accepted rounds after that; councils can converge on something a human finds wrong.

## Step 3 — Define the top

- **Target**: e.g. "all cases pass on dev and selection" or "candidate beats both best competitors in every category in ≥2 consecutive rounds".
- **Stop conditions** (any): target reached; budget cap (rounds/hours/$); tripwire fires; gate unrecoverable after M attempts; stall persists after branching (Step 4).
- Expect steep diminishing returns near the top. Budget for it.
- **Two-phase pattern** for efficiency goals: reach target and commit; then minimize cost while holding target. Never both at once.
- The top is a choice; after hitting it, name the next hill.

## Step 4 — Search strategy (adaptive: greedy, then branch)

Greedy hill climbing wins when small changes often help and stalls when they rarely do. Don't guess which regime you're in; let greedy probe it.

**Phase 1 — Greedy.** One incumbent. One coherent change per round, accept only on strict improvement beyond noise, else revert. Keep an **archive** of every scored candidate (commit/branch + score), not just the incumbent.

**Stall trigger.** No accepted improvement in W rounds (default W = 8; lower if evals are expensive) → Phase 2. Don't stop at the first plateau.

**Phase 2 — Branch.** Fork B branches (2–3) from the top-B archive entries. Each branch's first change must differ from the others at the **mechanism** level (different approach or algorithm family, not a parameter tweak). Advance branches round-robin with the same accept rule per branch. Within a branch:
- stuck *near the start* → push a deeper, structural change;
- stuck *after scattering* across unrelated ideas → narrow to refining the last thing that worked.
Focused, sustained direction beats diversity for its own sake; don't spawn many shallow branches.

**Reject clones.** A candidate whose per-case results are identical to its parent is not progress; discard it even if the scalar ticks up from noise.

**Cheap/expensive eval tradeoff.** If evals are expensive or the case pool is small, score each round on a fresh random sample of cases (e.g. 20) and keep a running pairwise/Elo-style record across rounds instead of one big fixed selection set; more rounds with noisy selection usually beats few rounds with precise selection. Still run the held-out test once at the end.

## Step 5 — Loop protocol (goes into the agent prompt)

1. Score baseline; log it.
2. Read the last round's per-case diagnostics and which cases flipped (pass→fail, fail→pass). Pick the change that targets the largest failing cluster.
3. **Draft → quick check → revise**: test the draft on a few previously-failing cases, fix within the same context, then run the full score.
4. Apply the accept rule (Step 4). Commit accepted changes with score in the message; revert otherwise.
5. Append to `climb-log.md`: round, branch, hypothesis, change, scores, flipped cases, kept/reverted, lesson learned.
6. Long runs: start each round (or every few rounds) in a fresh session that reads `climb-log.md` and the archive, rather than one ever-growing context.
7. Stop on any stop condition. Report final scores on dev, selection, and held-out test; tripwire status; anything suspected of gaming.

**Forbidden, stated explicitly in the prompt:** editing scorer/tests/rubric/fixtures; deleting, skipping or weakening tests; special-casing eval inputs; hard-coding expected outputs; reading evaluator internals; telling judges what to score. Include verbatim: **"If the scorer or a test appears wrong, STOP and report it. Do not work around it."** That one instruction sharply cuts test-gaming.

## Delivery

Default: output both documents **inline** in the response, so the user copies them straight from the chat. Write files only when the user asks for files, or when running in an agentic coding environment where files are the natural handoff.

- **Block 1 — "Paste into a fresh climbing session."** One self-contained block: the full `HILL_CLIMB.md` content, with the agent prompt at the end. Its first instruction to the climber: save this block verbatim to `HILL_CLIMB.md` in the workspace before doing anything else (later rounds start fresh sessions that need to re-read it from disk).
- **Block 2 — "Keep private. Do not paste into the climber."** The `SCORER_PRIVATE.md` content.
- **Fence safety:** the documents contain ``` code fences, so wrap each block in a four-backtick fence (````markdown … ````) so it renders and copies intact.
- **Scorer scaffold** is code the user will run and edit; deliver it as a file (or a separate code block if no file tool exists), never buried inside Block 1.
- Label the blocks with plain headers above them; no other commentary between them.

## Output format

The climber must not know which cases are held out or which are tripwires, or those mechanisms stop working. So split the output:

**`SCORER_PRIVATE.md`** (Block 2) — never enters the climber's session or workspace; the user keeps it, or stores it where the climber can't read it:
```
# Scorer private: <name>
## Objective, bucket, readiness gate, assumptions, design rationale
## Held-out test set (location, how to run it, when: once at end)
## Tripwire cases (contents, expected behavior, what firing means)
## Selection-set contents (climber sees only its aggregate score)
## Known gaming risks + how each is blocked
## Rubric version history
```

**`HILL_CLIMB.md`** (Block 1) — pasted into the climber's session, which saves it to its workspace:
```
# Hill Climb: <name>
## Objective (one sentence) and what "better" means
## Artifact under change (paths / scope) and read-only paths
## Scorer (command or council spec; gates; primary; secondary; diagnostics format; rubric version)
## Data visibility (dev: full diagnostics; selection: aggregate only; "additional hidden cases exist")
## Baseline (measured value, N runs, mean ± spread)
## Target & stop conditions
## Search strategy (greedy W, branch count B, sampling if evals are expensive)
## Forbidden moves + the STOP instruction
## Logging (climb-log.md format, archive format)
## Agent prompt
```

Do not name specific gaming risks in `HILL_CLIMB.md` beyond the forbidden moves; a list of known exploits is a menu.

The **Agent prompt** is self-contained and assumes the reader has zero context from the design conversation: scorer command or council instructions, loop protocol, search strategy, stop conditions, forbidden moves, STOP instruction, logging. Write it so the agent can run for hours without asking questions. Before delivering, re-read it as a stranger would: anything that only makes sense given this conversation goes into the spec explicitly.

If bucket A and no eval exists yet, scaffold the scorer (the JSON contract above) and make building the eval set phase 0.

## Step 6 — Handoff (three stages, separate sessions)

1. **Design** (this skill): interrogation, both blocks, scorer scaffold.
2. **Build and verify the scorer**, in this session or a dedicated one, never in the climbing one: implement the eval, run the baseline N times, confirm tripwires fail on the baseline, confirm the scorer is read-only to the climber, record the measured baseline in `HILL_CLIMB.md`. A climb on an unverified scorer is wasted compute.
3. **Climb**: a fresh agent session that receives only `HILL_CLIMB.md`, the read-only scorer, and the artifact. It never sees this conversation or `SCORER_PRIVATE.md`. Held-out and tripwire runs are triggered from outside the climber (by the user or a separate script) at checkpoints and at the end.

End your response by telling the user these three stages in two or three sentences.

For worked examples and a pairwise judge prompt, read `references/examples.md`.
