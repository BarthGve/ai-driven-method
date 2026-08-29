---
description: Release next → main — bump VERSION, tag, wiki per US, board shipped
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
---
# dm-release — Production release (`next` → `main`)

Work from the repository base on branch **`next`** (integration). Never release from a feature branch.

## Step 1 — Candidates
List **parent** US Issues currently in status `test` (children already merged into `next`). Use `bash .dm/lib/dm-board.sh status-get <story-id>` for each story id in docs/stories.md; keep those whose status is exactly `test`.

No parent in `test` → STOP: "Nothing to release — ship tickets into next until their parent US reaches test."

Present the candidate US ids (and their children) to the user.

## Step 2 — Semver
AskUserQuestion: bump type — options major / **minor** (default) / patch.

## Step 3 — Bump on `next`
```bash
bash .dm/lib/dm-version.sh bump <major|minor|patch>
```
Commit `VERSION`, `CHANGELOG.md`, and any synced `package.json` / `pyproject.toml` on `next` (message like `chore: release v$(cat VERSION)`). Push `next`.

## Step 4 — PR into `main`
```bash
gh pr create --base main --head next --title "Release v$(cat VERSION)" --body "…"
```
Do **not** merge in this command unless the user explicitly confirms an auto merge. Default: stop at the open PR.

## Step 5 — After MERGED only
Prove merge: `gh pr view <url> --json state --jq .state` must be `MERGED`. Then:

1. Tag: `git tag "v$(cat VERSION)"` on the merge commit / `main`, push the tag.
2. Wiki (one page per US in this release):
   ```bash
   bash .dm/lib/dm-wiki.sh publish "$(pwd)" "$(cat VERSION)" <story-id...>
   ```
3. Board — for each released parent and **every** of its children:
   ```bash
   bash .dm/lib/dm-board.sh status-set <story-id> shipped
   bash .dm/lib/dm-board.sh status-set <story-id>/<ticket-id> shipped
   ```
   Optionally `parent-sync <story-id>` after children are shipped.

End with: "Released vX.Y.Z — wiki updated, board shipped." or the open PR URL if still awaiting merge.
