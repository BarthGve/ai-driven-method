---
description: Open the ticket's PR into next; merge per the project's ship strategy (manual by default). Use when the last review round says Ship allowed yes. Not for production (/dm-release).
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
Run: `grep '^Ship allowed:' docs/reviews/<story-id>/<ticket-id>.md | tail -n 1 | grep -q '^Ship allowed: yes'` — the review appends rounds, only the last verdict counts.
If the file is missing or the command fails, STOP immediately: "Ship blocked — review missing or negative. Run /dm-review <story-id> <ticket-id>." Nothing below runs without a passing gate.

Board gate (child only), same as execute:
```bash
bash .dm/lib/dm-board.sh require-ready <story-id>/<ticket-id>
```
Exit non-zero → STOP: move the child to `ready` (or it must already be `in progress`) first. Parent US never uses `ready`.

Require `docs/product/<story-id>.md` (from `/dm-docs`). Missing → STOP: "Product doc required — run /dm-docs <story-id>."

Then proceed:
1. Without switching branches, commit `docs/reviews/<story-id>/<ticket-id>.md` on the already verified ticket branch if not already committed (the PR must carry its review). Then run the `full` check through the witness (`bash .dm/lib/dm-witness.sh full -- <full command>`, AGENTS.md Checks): it is skipped when the reviewed content already passed. Failing tests → stop.
2. Conflict with `next` — another ticket may have landed on the same files since this branch was cut (two migrations, one shared module). Check, without touching the tree:
   ```bash
   git fetch origin next
   git merge-tree --write-tree --quiet origin/next HEAD   # exit 0 = merges cleanly, 1 = conflict
   ```
   - Exit 0 → continue; the squash merge takes care of a branch that is merely behind.
   - Exit 1 → `git rebase origin/next`. If the rebase stops on a conflict: `git rebase --abort` and STOP: "Ship blocked — conflict with next on <files>. Fix via /dm-execute <story-id> <ticket-id> (fix mode): rebase on origin/next and resolve, regenerating a migration rather than hand-merging it." If it applies cleanly: rerun `full` through the witness (the content changed, so it really runs). Failing tests → STOP, same fix-mode message. The rebased branch is pushed with `--force-with-lease` in the next step.
3. If a PR for `feature/<story-id>/<ticket-id>` already exists, don't open a duplicate — check its state: MERGED → jump straight to the Cleanup step; OPEN → push the branch (`git push --force-with-lease origin feature/<story-id>/<ticket-id>` after a rebase) and continue. Otherwise push the branch and open a clean PR from `feature/<story-id>/<ticket-id>` to **`next`** (never `main`): `gh pr create --base next --head feature/<story-id>/<ticket-id> …`. Clear title, structured description (what, why, how to test), readable diff. Include the review verdict (max severity + findings summary) in the PR body.
4. Read the ship strategy from AGENTS.md ("Ship strategy" section). No section, or no explicit `auto` → the mode is manual.

## Step 4 — Merge (per the ship strategy)

**Always squash.** One ticket = one commit on `next`. The working commits stay on the branch, the history stays readable, and no merge commit is created.

- **manual (default): do NOT merge.** End with: "PR opened: <url> (base: `next`). Merging is yours to decide (human review, protected branch, CI) — **squash-merge it**. After merging, rerun /dm-ship <story-id> <ticket-id> to clean up the ticket worktree."
- **auto**: wait for the PR's checks first — a protected `next` refuses the merge while a required check runs, and an unprotected one would take an unchecked diff. Checks register a few seconds after a push: "no checks reported" right away means "not yet", and only after a minute of it "none in this repo".
  ```bash
  for _ in $(seq 12); do
    out="$(gh pr checks <url> --watch --fail-fast --interval 15 2>&1)" && break
    echo "$out" | grep -q "no checks reported" || { echo "$out"; echo "Ship blocked — check failed, not merged: <url>"; exit 1; }
    sleep 5
  done
  gh pr merge <url> --squash --delete-branch=false
  ```
  A failed check → STOP without merging: "Ship blocked — check failed: <check + URL>. Fix via /dm-execute <story-id> <ticket-id> (fix mode)." A merge refused because `next` moved meanwhile → rerun /dm-ship (step 2 rebases). Then run the Cleanup step. End with: "Ticket merged into `next`. Cycle complete for this ticket."

Never merge in manual mode, even if everything is green — the gate authorizes the ship, the human decides it. Never open or merge a PR into `main` from this command; production is `/dm-release` (`next` → `main`).

## Final step — Cleanup (ONLY after a PROVEN merge)
Never clean up on the promise of a merge — only on proof:
1. Verify: `gh pr view feature/<story-id>/<ticket-id> --json state,mergedAt --jq '.state'` must return exactly `MERGED`. An OPEN PR, a closed-unmerged PR, or an "about to be merged" does NOT qualify: skip cleanup entirely.

   Do NOT use `git merge-base --is-ancestor` here: a squash merge rewrites the work into a new commit, so the branch's commits are never ancestors of `next`. The check would fail on every correctly merged ticket and no branch would ever be cleaned up.
2. Verify the dedicated ticket worktree is clean. Run the `isolation` teardown of the AGENTS.md Checks table from inside it, when one is recorded (a failure is reported, not blocking). Then remove that exact worktree with
   `git worktree remove <repository-base>/.worktrees/<story-id>/<ticket-id>`. A dirty worktree is
   a hard stop; never use `--force`.
3. Only after the worktree is gone, delete the branch, local and remote:
   `git branch -D feature/<story-id>/<ticket-id>` and `git push origin --delete feature/<story-id>/<ticket-id>`.

   `-D` is required, again because of the squash: `-d` refuses a branch git
   considers unmerged, which is every squashed branch. The safety therefore
   rests entirely on step 1 — never remove the worktree or branch without the
   `MERGED` proof.
4. Board — child to `test`, then derive parent:
   ```bash
   bash .dm/lib/dm-board.sh status-set <story-id>/<ticket-id> test
   ```
   (`status-set` on a child re-derives the parent US: `test` only when every child is `test` or `shipped`; parent never uses `ready`.)

The content is on `next`, the audit trail is in the merged PR: the ticket branch has no further use.
