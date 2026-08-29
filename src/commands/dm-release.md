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

## Step 3 — Bump on `next` (once per release)
Refuse a second bump if `VERSION` on `next` already differs from `main` **and** a release PR is already open:

```bash
git fetch origin main next
main_ver="$(git show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || true)"
next_ver="$(tr -d '[:space:]' < VERSION)"
if [ -n "$main_ver" ] && [ "$next_ver" != "$main_ver" ]; then
  open="$(gh pr list --base main --head next --state open --json url --jq '.[0].url // empty')"
  if [ -n "$open" ]; then
    echo "Release already in flight ($open). VERSION on next is $next_ver vs main $main_ver. Do not bump again — squash-merge that PR."
    exit 1
  fi
fi
```

If that check passes:
```bash
bash .dm/lib/dm-version.sh bump <major|minor|patch>
```
Commit `VERSION`, `CHANGELOG.md`, and any synced `package.json` / `pyproject.toml` on `next` (message like `chore: release v$(cat VERSION)`). Push `next`.

## Step 4 — PR into `main`
```bash
gh pr create --base main --head next --title "Release v$(cat VERSION)" --body "…"
```
Do **not** merge in this command unless the user explicitly confirms an auto merge. Default: stop at the open PR.

**Always squash-merge** this PR (`gh pr merge --squash` or the GitHub squash-merge button). One release = one commit on `main`. Never merge-commit `next` into `main`.

## Step 5 — After MERGED only
Prove merge: `gh pr view <url> --json state --jq .state` must be `MERGED`. Then:

1. Fetch `origin/main` and tag **that** SHA (the squash commit on `main`), never a `next` SHA:
   ```bash
   git fetch origin main
   ver="$(tr -d '[:space:]' < VERSION)"
   main_sha="$(git rev-parse origin/main)"
   git tag "v${ver}" "$main_sha"
   git push origin "v${ver}"
   ```
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
