---
description: Open the PR into next; merge per the project's ship strategy (manual by default)
argument-hint: <story id> <ticket id>
allowed-tools:
  - Read
  - Bash
---
You are shipping a **ticket**. Target: $ARGUMENTS

Resolve $ARGUMENTS to `<story-id>` and `<ticket-id>` (`s<number>-<slug>` and `t<number>-<slug>`). The review file `docs/reviews/<story-id>/<ticket-id>.md` must exist. Full work id: `<story-id>/<ticket-id>`.

Locate `.worktrees/<story-id>/<ticket-id>`, verify its branch is exactly
`feature/<story-id>/<ticket-id>`, and run the entire command from that absolute
worktree. Missing worktree, wrong branch, detached HEAD or repository base →
STOP; never checkout the feature branch in the repository base directory.

## Step 0 — Gate (fail-closed, mechanical)
Run: `grep -q '^Ship allowed: yes' docs/reviews/<story-id>/<ticket-id>.md`
If the file is missing or the command fails, STOP immediately: "Ship blocked — review missing or negative. Run /dm-review <story-id> <ticket-id>." Nothing below runs without a passing gate.

Require `docs/product/<story-id>.md` (from `/dm-docs`). Missing → STOP.

Then proceed:
1. Without switching branches, commit `docs/reviews/<story-id>/<ticket-id>.md` on the already verified ticket branch if not already committed (the PR must carry its review). Then verify the tests pass. Failing tests → stop.
2. If a PR for `feature/<story-id>/<ticket-id>` already exists, don't open a duplicate — check its state: MERGED → jump straight to the Cleanup step; OPEN → continue. Otherwise push the branch and open a clean PR from `feature/<story-id>/<ticket-id>` to **`next`** (never `main`): clear title, structured description (what, why, how to test), readable diff. Include the review verdict (max severity + findings summary) in the PR body.
3. Read the ship strategy from AGENTS.md ("Ship strategy" section). No section, or no explicit `auto` → the mode is manual.

## Step 4 — Merge (per the ship strategy)

**Always squash.** One ticket = one commit on `next`. The working commits stay on the branch, the history stays readable, and no merge commit is created.

- **manual (default): do NOT merge.** End with: "PR opened: <url> (base: `next`). Merging is yours to decide (human review, protected branch, CI) — **squash-merge it**. After merging, rerun /dm-ship <story-id> <ticket-id> to clean up the ticket worktree."
- **auto**: `gh pr merge <url> --squash --delete-branch=false`, then run the Cleanup step. End with: "Ticket merged into `next`. Cycle complete for this ticket."

Never merge in manual mode, even if everything is green — the gate authorizes the ship, the human decides it. Never open or merge a PR into `main` from this command; production is `/dm-release` (`next` → `main`).

## Final step — Cleanup (ONLY after a PROVEN merge)
Never clean up on the promise of a merge — only on proof:
1. Verify: `gh pr view feature/<story-id>/<ticket-id> --json state,mergedAt --jq '.state'` must return exactly `MERGED`. An OPEN PR, a closed-unmerged PR, or an "about to be merged" does NOT qualify: skip cleanup entirely.

   Do NOT use `git merge-base --is-ancestor` here: a squash merge rewrites the work into a new commit, so the branch's commits are never ancestors of `next`. The check would fail on every correctly merged ticket and no branch would ever be cleaned up.
2. Verify the dedicated ticket worktree is clean, then remove that exact worktree with
   `git worktree remove <repository-base>/.worktrees/<story-id>/<ticket-id>`. A dirty worktree is
   a hard stop; never use `--force`.
3. Only after the worktree is gone, delete the branch, local and remote:
   `git branch -D feature/<story-id>/<ticket-id>` and `git push origin --delete feature/<story-id>/<ticket-id>`.

   `-D` is required, again because of the squash: `-d` refuses a branch git
   considers unmerged, which is every squashed branch. The safety therefore
   rests entirely on step 1 — never remove the worktree or branch without the
   `MERGED` proof.
4. Board: move the **child** Issue to `test`. If every sibling child of the parent US is `test` or `shipped`, move the **parent US** to `test`. Otherwise leave the parent where it is.

The content is on `next`, the audit trail is in the merged PR: the ticket branch has no further use.
