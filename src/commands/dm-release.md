---
description: Release next → main — bump VERSION, tag, wiki per US, board shipped. Use when parent stories are in test. Not for shipping one ticket into next (/dm-ship).
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
---
# dm-release — Production release (`next` → `main`)

Work from the repository base on branch **`next`** (integration). Never release from a feature branch.

## Step 1 — Candidates
List **parent** US Issues currently in status `test` (children already merged into `next`). Run `bash .dm/lib/dm-board.sh status-all` once and, for each story id in docs/stories.md, keep those whose line says exactly `test`.

No parent in `test` → STOP: "Nothing to release — ship tickets into next until their parent US reaches test."

Present the candidate US ids (and their children) to the user.

## Step 2 — Semver
AskUserQuestion: bump type — options major / **minor** (default) / patch.

## Step 3 — Bump through a PR into `next` (once per release)
`next` is protected (no direct push, see /dm-init): the bump reaches it through a short-lived
`release/v<version>` PR, prepared in a throwaway worktree of `origin/next` — the repository
base is never reset or committed to.

```bash
git fetch origin main next
bump_pr="$(gh pr list --base next --state open --json url,headRefName --jq '[.[] | select(.headRefName | startswith("release/"))][0].url // empty')"
if [ -n "$bump_pr" ]; then
  echo "Bump PR into next still open ($bump_pr). Squash-merge it, then rerun /dm-release."
  exit 1
fi
main_ver="$(git show origin/main:VERSION 2>/dev/null | tr -d '[:space:]' || true)"
next_ver="$(git show origin/next:VERSION | tr -d '[:space:]')"
if [ -n "$main_ver" ] && [ "$next_ver" != "$main_ver" ]; then
  open="$(gh pr list --base main --head next --state open --json url --jq '.[0].url // empty')"
  if [ -n "$open" ]; then
    echo "Release already in flight ($open). VERSION on next is $next_ver vs main $main_ver. Do not bump again — squash-merge that PR."
    exit 1
  fi
  echo "Bump v$next_ver already on next — skip the bump."
fi
```

A bump already on `next` (an earlier run stopped after it) → skip to "Realign" below. Otherwise:
```bash
wt="$(mktemp -d)/release"
git worktree add -q --detach "$wt" origin/next
( cd "$wt" && bash .dm/lib/dm-version.sh bump <major|minor|patch> )
```
In `$wt`, commit `VERSION`, `CHANGELOG.md` and any synced `package.json` / `pyproject.toml`
(message like `chore: release v<version>`), then:
```bash
ver="$(tr -d '[:space:]' < "$wt/VERSION")"
git -C "$wt" push origin "HEAD:refs/heads/release/v${ver}"
git worktree remove "$wt"
url="$(gh pr create --base next --head "release/v${ver}" --title "chore: release v${ver}" --body "Version bump for the release of v${ver}.")"
out="$(gh pr checks "$url" --watch --fail-fast --interval 15 2>&1)" || {
  echo "$out" | grep -q "no checks reported" || { echo "$out"; echo "Bump PR check failed — not merged: $url"; exit 1; }
}
```
"no checks reported" is not a failure (a repo without checks). Then `gh pr merge "$url" --squash --delete-branch` — this bump PR is the release
gesture the user asked for.

Realign: from the repository base, on `next` with no uncommitted change to `VERSION` or
`CHANGELOG.md`, `git merge --ff-only origin/next` after `git fetch origin next`. It cannot
fast-forward → STOP and say why; never reset.

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
3. Board — for **every** child of each released parent (the parent follows: it turns `shipped` with its last child):
   ```bash
   bash .dm/lib/dm-board.sh status-set <story-id>/<ticket-id> shipped
   ```

End with: "Released vX.Y.Z — wiki updated, board shipped." or the open PR URL if still awaiting merge.
