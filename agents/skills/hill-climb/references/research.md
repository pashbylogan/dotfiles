# Research behind the rules

Read when the user asks "why" or when a design choice is disputed. Claims marked [derived] are this skill's own extrapolations, not direct findings.

## Search strategy
- **FML-bench (Zou et al., 2026, arXiv 2605.17373).** Six research-agent strategies on 18 ML tasks. Greedy hill climbing (Karpathy's autoresearch) nearly tied the best tree-search agent overall but ranked first on tasks where small changes often help and sixth of seven where they rarely do. An adaptive agent (greedy until the best-so-far curve stalls, then fork branches from the top-N candidates, each branch's first idea differing at the mechanism level, not hyperparameters) beat all others. Early improvement and directionally focused exploration predicted success; solution diversity, token spend, and wall-clock did not. They also steered stalled branches: deeper changes if stuck near baseline, narrower refinement if scattered. → Step 4.
- **RoboPhD (Borthwick et al., 2026, arXiv 2604.04347).** Elo tournament evolution beat GEPA and autoresearch on 3 of 4 benchmarks under a fixed 1,500-evaluation budget; greedy autoresearch won only the simplest task (<90-line solution). Useful mechanisms: per-problem diagnostics returned with scores; comparative error reports showing where candidates diverge; fresh session per iteration (avoids long-context degradation) combined with draft-then-test-then-revise inside that session ("Deep Focus", improved all 4 benchmarks in ablation); discarding behavioral clones; fresh random case samples each round. Smaller validation sets improved results in all 8 paired comparisons because freed budget bought more iterations. → Steps 2a, 4, 5.
- **GEAR (Jeddi et al., 2026, arXiv 2605.13874).** Replacing autoresearch's single-incumbent climb with a population-based frontier search improved results under equal compute. → archive + branching.
- [derived] Default W = 8 and B = 2–3 are scaled down from FML-bench's 100-step setting (W = 50) for typical agent budgets of tens of rounds. Tune to budget.

## Scorer integrity (reward hacking)
- **RoboPhD ethics note.** Their autoresearch port found an oracle exploit: it read future data from the simulator's internal state and posted an impossible score. Fixed by redesigning the evaluator API. → sandbox the evaluator boundary.
- **ImpossibleBench (Zhong, Raghunathan, Carlini; ICLR 2026).** Coding agents given tests that contradict the spec frequently "pass" by modifying tests, special-casing, or other exploits despite instructions. Hiding tests cut cheating to near zero but hurt legitimate performance; a strict prompt telling the agent to stop if tests look flawed cut GPT-5's cheating on one variant from 93% to 1%. → read-only scorer, STOP instruction.
- [derived] Tripwire cases apply ImpossibleBench's method as a live monitor inside the user's own eval.

## Judges
- **Zheng et al. 2023 (MT-Bench / Chatbot Arena) and follow-ups.** LLM judges show position bias, verbosity bias, and self-preference (stronger within a model family). Standard mitigations: swap order and require agreement, judges from other families, rubric with anchors, reasoning before verdict. Pairwise comparison tracks human preference better than absolute scales. → Step 2b.
- **"The Coin Flip Judge?" (arXiv 2606.13685).** Judge reliability splits into run-to-run instability, systematic bias, prompt sensitivity, and cross-judge disagreement; forced-choice verdicts can overstate real quality gaps. → allow "tie", require multi-judge consensus.
- **Theo Browne, "Agents Sucked At UI (Until Today)" (Nov 2026).** Same screenshots scored 6→9 in one framing and 7.0→7.4 in another; stating the target to judges likely inflated scores; unchanged competitor screenshots drifted upward across rounds. → hide targets, re-score a frozen baseline, pointwise scores for reporting only.
- [derived] The accept rule (no judge prefers incumbent, majority prefers candidate) and the ~10-pair human calibration are practical choices, not tested thresholds.

## Eliciting the objective
- **Shankar et al., "Who Validates the Validators?" (UIST 2024, arXiv 2404.12272).** Studying practitioners building LLM evaluators, they found "criteria drift": people need criteria to grade outputs, but grading outputs is what helps them define the criteria, so criteria can't be fully fixed before looking at real outputs. Participants kept refining criteria and even changed earlier grades. → Step 1.5: grade-to-define, versioned rubric, early human checkpoint.
- [derived] The 7-check gate, the 3-question/3-round caps, and "propose, then ask" are practical design choices, not tested protocols.
