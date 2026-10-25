---
name: cleanup
description: Tear down the debris left after a piece of work has landed: merged branches and their remotes, this task's worktree, generated artifacts and session scratch files. Use when work is merged and the user is moving on, says "clean up", "tidy up" or "clean up after this", or invokes /cleanup. Read-only until it has shown a manifest and been told to go.
---

# Clean up after a landed task

Everything here is reversible except the last step, and only because the reflog is not
a filesystem. The order below exists to keep it that way. **When a check does not pass,
report the item and move on; never widen a predicate to make something deletable.**

Harnesses sweep some of this on their own, and only worktrees:

- Claude Code removes subagent and background-session worktrees under `.claude/worktrees/`
  once they pass `cleanupPeriodDays` (default 30), skipping changed or unpushed ones.
- T3 Code removes worktrees under `~/.t3/worktrees/` by its Storage cleanup settings
  (inactive, settled, merged, unchanged). Branches and thread history are kept.

This skill is for not waiting, and for the branches, remote branches and scratch files
no harness touches.

## Merge targets

A branch is done when its work is in every branch it was meant to reach. Take that list,
in order of precedence, from:

1. The project's own instructions (its AGENTS.md or CLAUDE.md), or a context layer serving
   the repo (`[branch].pr_bases` in its project.toml), when they name the PR bases.
2. Otherwise the remote's default branch: `git symbolic-ref --short refs/remotes/origin/HEAD`.

Protected, never deleted: every merge target, the default branch, and any long-lived
environment branch the project names. Say which targets you used in the manifest.

## Phase A: inventory (read-only, always safe to run)

1. **`git fetch --prune` first.** Every merged or unmerged judgment below is garbage against
   stale remote refs. Not optional.
2. `git worktree list --porcelain`, and `git rev-parse --show-toplevel` to mark the one
   you are inside.
3. `git branch -vv`, then classify each local branch by the predicates below.
4. For each candidate worktree: `git -C <wt> status --porcelain`, an unpushed-commit
   check, and `git -C <wt> ls-files --others --ignored --exclude-standard`.
5. Check for a stale sequencer, and run `git stash list`, **to report, never to act**.
6. `du -sh` the scratch roots this session actually used. List them; delete nothing yet.

## Phase B: the manifest

Print two sections and stop:

- **Will delete**: predicate passed, with the evidence that passed it.
- **Needs your call**: predicate failed, with `git log origin/<target>..<branch> --oneline`
  or the relevant diff, so the human is deciding on evidence rather than on your summary.

Ask **once**, here. Per-item prompts for things that already passed are friction.

## Phase C: execute, in this order

Reversibility descending. Worktrees before branches, because a checked-out branch cannot
be deleted.

1. Stale sequencer directory
2. Regenerable build outputs
3. `git worktree remove` (never `--force`, never `rm -rf`)
4. `git branch -d` (never `-D`)
5. `git push origin --delete` for the matching remotes
6. Scratch directories: last, being the only irreversible non-git step
7. Re-run the inventory and confirm it comes back empty

## Predicates

**Delete a local branch**: all of:

- `git merge-base --is-ancestor <branch> origin/<target>` for **every** merge target.
  Merged to one target with another's PR still open is not done, and deleting orphans the
  pending PR. Ancestry survives a PR being reverted later, which is correct: the commits
  are still in history.
- The branch is not checked out in any `git worktree list --porcelain` entry.
- It is not protected.
- An ancestor of only some targets? Check `gh pr list --head <branch> --state open` (or the
  forge's equivalent). An open PR means not done: a *needs your call*, not a delete.
- Then `-d`, never `-D`, so git independently double-checks you.

An upstream marked `gone` is **not** evidence of merged. Forges delete on merge, and
people also delete by hand.

**Squash or rebase merges**: ancestry never holds, so every branch reads as unmerged.
That fails safe, but it looks broken. In a repo that merges that way, a branch qualifies
when the forge shows a merged PR from it into each target whose head commit equals the
branch tip (`gh pr list --head <branch> --state merged --json baseRefName,headRefOid`).
A tip that moved after the merge is *needs your call*. `-d` then refuses, because git sees
no ancestry: show the evidence in the manifest, and delete with `-D` only for branches it
lists, with the user's go. This is the one exception to never `-D`.

**Delete an integration branch**: a branch cut from one target to carry a conflicted PR
into it, named by the project's convention (for example `<feature>-<env>` or
`<feature>-<env>-N`). It holds that target's own history, so it can never be an ancestor
of the others, and the local-branch rule would keep it forever. It qualifies on all of:

- `git merge-base --is-ancestor <branch> origin/<env>`. Everything on it is already in
  its own target, so deleting it loses nothing.
- `gh pr list --head <branch> --state open` is empty.
- It is not checked out in any worktree, and it is not protected.

Whether the feature is done stays the feature branch's own question: an unmerged feature
branch is still *needs your call* after its integration branch is gone. Run
`git branch -u origin/<env> <branch>` before `git branch -d`, so `-d` checks against that
target rather than the checked-out HEAD. Still never `-D`.

**Delete a remote branch**: the local predicate passed, *and* `origin/<branch>` is
itself an ancestor of every merge target (an integration branch: of its own
`origin/<env>`). Local and remote diverge.

**Remove a worktree**: it is *this task's* worktree. Never sweep a harness's worktree
folder (`.claude/worktrees/`, `~/.t3/worktrees/`) or a ship run's `wt-*` folders of other
tickets: the others belong to live parallel sessions, and removing one destroys work in
progress. It must not be your cwd, its `status --porcelain` must be empty but for
known-regenerable paths, and its branch must have passed the branch or integration-branch
predicate. An integration worktree this task created counts as this task's. `git worktree
remove` refuses a dirty tree on its own: that refusal is the second lock, so do not force
past it.

**A gitignored file inside a worktree**: regenerable patterns (build dirs, `__pycache__`,
`.metrics/`, coverage reports) delete freely. Anything else: compare against the
authoritative copy outside the worktree. Byte-identical: delete. Differs, or has no
counterpart: *needs your call*, with the diff. **Never auto-copy it back**: a stale copy
overwriting live state is the worse failure.

**A stale sequencer**: `.git/sequencer` exists *and* `git status` reports no revert or
cherry-pick in progress. Remove only the sequencer directory. If an operation genuinely is
in progress, stop the whole skill.

**A scratch directory**: the path is one this session named and used. Never glob `/tmp`.
Show path and size before deleting.

## Never

- `git branch -D` (outside the squash-merge exception above), `git worktree remove --force`,
  or `rm -rf` on a worktree
- Touch the stash. `pop`, `drop`, `clear` are all forbidden: the stack is shared across
  worktrees and the entry may be another session's. Report entries; act on none.
- `git add`, `git commit`, or `git push` anything but a `--delete` of a qualifying remote
- Touch any worktree other than this task's
- `git gc --prune=now` or expire the reflog: that reflog is the undo for every `-d`
- Run while a merge, rebase, or revert is in progress (the stale-sequencer removal is the
  one exception, and it applies precisely when nothing is in progress)
- Delete or overwrite a gitignored file that differs from its counterpart

## Ask, or don't

**Always the human's call**, listed with evidence rather than acted on: unmerged branches,
dirty worktrees, gitignored files that differ, any worktree not tied to this task, any
scratch path this session did not itself create.

**Never worth asking about**: branch deletions whose predicate passed, a clean worktree of
your own, regenerable build output, a stale sequencer.
