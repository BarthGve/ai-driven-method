# `/dm-continue` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/dm-continue` command that onboards an existing codebase (code + hand-written GitHub Issues) into the driven pipeline, without duplicating what `/dm-prd`, `/dm-init`, `/dm-stories` and `/dm-architect` already do.

**Architecture:** `/dm-continue` is a thin orchestrator. It produces one new artifact — `docs/onboarding.md`, product-level only — then chains the existing commands. It cannot mutate the GitHub board (the board does not exist yet at that point), so it only *proposes* an Issue mapping; `/dm-stories` executes the conversion later, after `/dm-init`.

**Tech Stack:** Markdown command files under `src/commands/` (the canonical source), Node.js built-in test runner (`node --test`), zero external dependencies. `bin/dm-build.mjs` propagates `src/commands/` to the Claude / Codex / Grok targets automatically.

**Spec:** `docs/superpowers/specs/2026-08-31-dm-continue-design.md`

## Global Constraints

- Edit **only** `src/` — `src/AGENTS.md` is the sole tracked source of workflow rules. Root `AGENTS.md` and `CLAUDE.md` are gitignored local-install artifacts and must not be created or edited.
- Do **not** apply the driven pipeline to this repository itself. Commit directly on `main` with `feat:` / `fix:` prefixes, matching the existing history.
- Run the test suite with `node --test tests/*.mjs` (the glob is required; `node --test tests/` fails with a directory argument).
- Baseline before starting: **70 tests pass, 0 fail** (67 + 3 regression tests added by the security fix in commit `90a8390`).
- No changes to `bin/dm-build.mjs`: it iterates `src/commands/`, so a new command file propagates to every target on its own.
- `docs/onboarding.md` is **product-level only**. Code structure, conventions, patterns and stack stay the job of `/dm-architect` via the `codebase-analysis` skill.
- No GitHub Issue written by the user is renamed, moved or closed without explicit per-Issue confirmation.
- **Decision — no `src/templates/onboarding.md`.** Other deliverables use a template injected with `@templates/x.md`, but `tests/templates.test.mjs` enumerates templates individually (only `prd` today), so nothing requires one. The structure stays inline in the command body: one file instead of two, and the section headings are a cross-file contract that is easier to keep honest next to the instructions that produce them.
- The headings written into `docs/onboarding.md` are **English verbatim anchors**, matching the language of the command bodies. `/dm-stories` greps them literally; a translated heading silently breaks the handoff.

---

### Task 1: Register `dm-continue` in the command gate

The `required` array in `tests/commands.test.mjs` is the mechanical gate that every driven command exists. Adding the assertion first makes the whole plan test-driven: the suite goes red until the command file lands.

**Files:**
- Modify: `tests/commands.test.mjs:5-10` (the `required` array)

**Interfaces:**
- Produces: the failing gate that Task 2 satisfies. No code interface — this repo's "units" are markdown command files asserted by regex.

- [ ] **Step 1: Add `dm-continue` to the required array**

  In `tests/commands.test.mjs`, change the `required` array so the last line reads:

```javascript
const required = [
  "dm-prd", "dm-init", "dm-stories", "dm-stories-review", "dm-architect",
  "dm-design-system", "dm-research", "dm-design", "dm-plan", "dm-docs",
  "dm-execute", "dm-review", "dm-ship", "dm-release", "dm-orchestrator",
  "dm-status", "dm-help", "dm-continue",
];
```

- [ ] **Step 2: Run the suite and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | tail -12`

  Expected: FAIL — `1 fail`, on the test named `all dv commands exist`, with the assertion message `dm-continue` (the array's second `assert.ok` argument).

- [ ] **Step 3: Commit the failing gate**

```bash
git add tests/commands.test.mjs
git commit -m "test: require dm-continue command file"
```

---

### Task 2: Write the `/dm-continue` command

**Files:**
- Create: `src/commands/dm-continue.md`
- Test: `tests/commands.test.mjs`

**Interfaces:**
- Consumes: the `required` gate from Task 1.
- Produces: the file `src/commands/dm-continue.md`, whose body Tasks 3 and 5 refer to. It writes `docs/onboarding.md` containing a section titled `## Mapping des Issues ouvertes` with rows of the form `| #<N> | <title> | s<NN>-<slug> |` — Task 4 (`/dm-stories`) reads exactly that section and that row shape.

- [ ] **Step 1: Write the failing behaviour tests**

  Append to `tests/commands.test.mjs`:

```javascript
test("continue is read-only on the board and writes onboarding.md", () => {
  const t = readFileSync("src/commands/dm-continue.md", "utf8");
  assert.match(t, /docs\/onboarding\.md/);
  assert.doesNotMatch(t, /require-ready/);
  assert.doesNotMatch(t, /issue-create-us|issue-create-ticket|status-set/);
});

test("continue is fail-closed on an empty repo and on an already-framed project", () => {
  const t = readFileSync("src/commands/dm-continue.md", "utf8");
  assert.match(t, /STOP/);
  assert.match(t, /docs\/prd\.md/);
});

test("continue hands off to dm-prd", () => {
  assert.match(readFileSync("src/commands/dm-continue.md", "utf8"), /Next step: \/dm-prd/);
});
```

- [ ] **Step 2: Run the tests and verify they fail**

  Run: `node --test tests/*.mjs 2>&1 | tail -12`

  Expected: FAIL — 4 failures (the gate from Task 1 plus the three new tests), all because `src/commands/dm-continue.md` does not exist (`ENOENT`).

- [ ] **Step 3: Create the command file**

  Write `src/commands/dm-continue.md` with exactly this content:

```markdown
---
description: Onboard an existing codebase into the driven pipeline — baseline + Issue mapping
argument-hint: (none — reads the current repo)
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Write
  - AskUserQuestion
---
# dm-continue — Adopt driven on a project already under way

You are onboarding an **existing** project into driven. The code already runs; the
documentation does not exist yet. Your single deliverable is `docs/onboarding.md`.

`Bash` is for read-only queries (`git log`, `git ls-files`, `gh issue list`) and for
the docs commit at the end. Never mutate the board, never write through `gh`.

## Prerequisites (fail-closed)
- Source files must exist outside `docs/`, and the git history must hold more than one
  commit. Neither → STOP: "Empty repo — run /dm-prd instead."
- `docs/prd.md` must **not** exist. Present → STOP: "Project already framed — run /dm-status."

## What you must NOT do
- Do not analyse code structure, conventions, patterns or stack. `/dm-architect` already
  does that with the `codebase-analysis` skill; a second analysis here would be a second
  source of truth that drifts.
- Do not create, rename, close or move any Issue. The board does not exist yet:
  `.dm/lib/dm-board.sh` needs `.dm/config.json`, which only `/dm-init` writes. You only
  **propose** a mapping.
- Do not write `docs/prd.md`, `docs/stories.md` or `docs/architecture.md`. The commands
  that own those files come next in the chain.

## Gather the real state (read-only)
1. Inventory the product surface: entry points, routes/screens, main flows. Use Glob and
   Grep. You are answering "what does this app do for its users", not "how is it built".
2. Read the git history (`git log --oneline`) for what has already shipped and when.
3. If `gh auth status` succeeds, list the open and closed Issues:
   ```bash
   gh issue list --state open --limit 200 --json number,title,labels
   gh issue list --state closed --limit 200 --json number,title
   ```
   `gh` missing or unauthenticated → skip the mapping section, print an explicit warning,
   and write the baseline anyway. A missing board must never block documenting the product.

## Confirm with the user (AskUserQuestion, one at a time)
1. Product summary: state what you understood the app does in one sentence; ask them to
   confirm or correct it.
2. Baseline boundary: which of the flows you listed do they consider already shipped?
3. For each open Issue, propose an id `s<NN>-<short-slug>` and ask them to confirm, amend
   or exclude it. Record the answer; nothing is applied here.

## Write `docs/onboarding.md`
Sections, in this order:

1. `## What the app does` — the value loop and the users, as confirmed.
2. `## Shipped baseline` — the shipped flows, with the commits or dates that show it.
3. `## Remaining work (leads)` — non-contractual; `/dm-stories` owns the real breakdown.
4. `## Open issue mapping` — **this heading is a verbatim anchor**: `/dm-stories` greps for
   it literally. Do not translate it, do not reword it. A table, one row per open Issue,
   exactly this shape:

   | Issue | Title | Proposed story |
   | --- | --- | --- |
   | #12 | Export CSV | s03-export-csv |

   This section is a **proposal**. `/dm-stories` reads it after `/dm-init` and applies the
   conversion, one confirmation per Issue.
5. `## Closed issues (context)` — listed, never touched.

Write nothing you have not validated with the user.

## Commit
`next` does not exist yet at this stage. Commit on the default branch, docs-only, so the
`pre-commit` hook passes without a validated plan:

```bash
git add docs/onboarding.md && git commit -m "docs: onboarding baseline"
```

End with: "Baseline ready in docs/onboarding.md (N Issues mapped, nothing mutated). Next step: /dm-prd"
```

- [ ] **Step 4: Run the tests and verify they pass**

  Run: `node --test tests/*.mjs 2>&1 | tail -10`

  Expected: PASS — `73 pass, 0 fail`.

- [ ] **Step 5: Commit**

```bash
git add src/commands/dm-continue.md tests/commands.test.mjs
git commit -m "feat: add dm-continue for onboarding an existing project"
```

---

### Task 3: Add the brownfield mode to `/dm-prd`

`/dm-prd` currently locks a binary mode: clone or greenfield. A project onboarded by `/dm-continue` is neither — its perimeter is read from the existing app, not invented.

**Files:**
- Modify: `src/commands/dm-prd.md:15` (the "two product modes" sentence), `:19` (the mode question), and the question set that follows
- Test: `tests/commands.test.mjs`

**Interfaces:**
- Consumes: `docs/onboarding.md` as written by Task 2 — specifically the `## Baseline — déjà livré` and `## Ce que fait l'application` sections.
- Produces: `docs/prd.md` with the existing template structure, so `/dm-init` (unchanged) finds its precondition.

- [ ] **Step 1: Write the failing test**

  Append to `tests/commands.test.mjs`:

```javascript
test("prd offers a brownfield mode fed by onboarding.md", () => {
  const t = readFileSync("src/commands/dm-prd.md", "utf8");
  assert.match(t, /brownfield/i);
  assert.match(t, /docs\/onboarding\.md/);
});
```

- [ ] **Step 2: Run it and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | tail -12`

  Expected: FAIL — 1 failure on `prd offers a brownfield mode fed by onboarding.md`, `/brownfield/i` not matching.

- [ ] **Step 3: Edit `src/commands/dm-prd.md`**

  Replace line 15:

```markdown
driven supports three product modes: clone an existing SaaS, greenfield an original product, or brownfield — a project whose code already runs. Before anything else, lock the mode.
```

  Replace the mode question on line 19:

```markdown
   - **Mode: clone, greenfield, or brownfield?** If `docs/onboarding.md` exists, propose brownfield by default. Otherwise: if $ARGUMENTS clearly names a SaaS, confirm clone; if it is a product idea with no target, confirm greenfield. Do not skip this question.
```

  Add a third branch to the question set, after the `**If greenfield:**` block and before step 3:

```markdown
   **If brownfield:**
   - Read `docs/onboarding.md` first: the value loop, the users and the shipped baseline are already recorded and confirmed. Do not ask again what it answers — confirm it in one question.
   - Need and target users: pre-fill from the onboarding baseline, ask only for what is missing.
   - In / out of scope: the shipped baseline is **in** by definition. Score the remaining features 1-5; the graveyard still kills scope creep on what has not been built.
   - Kill mode and Target SaaS sections: write `n/a` (brownfield / existing product).
   - The angle: what does the next phase change or improve, beyond what already ships?
   - Constraints and success criteria: measurable outcomes on the features still to build.
```

- [ ] **Step 4: Run the tests and verify they pass**

  Run: `node --test tests/*.mjs 2>&1 | tail -10`

  Expected: PASS — `74 pass, 0 fail`. In particular the pre-existing test `prd next step is dm-init` still passes: the closing line is untouched.

- [ ] **Step 5: Commit**

```bash
git add src/commands/dm-prd.md tests/commands.test.mjs
git commit -m "feat: add brownfield mode to dm-prd"
```

---

### Task 4: Add an `issue-adopt` primitive to `dm-board.sh`

Adopting a hand-written Issue is **not** a rename. `cmd_status_set` resolves its target
through `issue_project_item_id`, which needs the Issue to already be a **project item**.
An Issue created by hand was never added to the board, so renaming it and calling
`status-set` moves nothing. The library already knows how to do this correctly —
`add_issue_to_project_backlog` (line 207) does item-add + set-to-backlog with a retry —
but it is a private shell function, unreachable from `main()`'s dispatch (line 313), which
only exposes `status-get|status-set|issue-create-us|issue-create-ticket|require-ready|parent-sync`.

This task exposes it. It is the only shell change in the plan.

**Files:**
- Modify: `src/lib/dm-board.sh` (new `cmd_issue_adopt`, plus a dispatch case and the usage string in `main()`)
- Modify: `tests/fixtures/gh-stub.sh` (the `issue edit` case ignores `--title`)
- Test: `tests/board-parse.test.mjs`

**Interfaces:**
- Consumes: the existing private `add_issue_to_project_backlog <url> <key>` and `dm_config_repo`.
- Produces: `bash .dm/lib/dm-board.sh issue-adopt <key> <issue-number> <title>` — renames issue `<number>` to `[<key>] <title>`, adds it to the project, sets it to `backlog`. Task 5 calls exactly this signature.

- [ ] **Step 1: Teach the gh stub to record `--title`**

  In `tests/fixtures/gh-stub.sh`, inside the `*"issue edit"*` case, add the title handling
  next to the existing body-file and label handling:

```javascript
      const t=get("--title")||get("-t");
      if (t) issue.title=t;
```

  and include it in the recorded edit:

```javascript
      s.edits.push({kind:"issue-edit", number:Number(num), title:issue.title, labels:issue.labels||[], body:issue.body||""});
```

- [ ] **Step 2: Write the failing test**

  Append to `tests/board-parse.test.mjs`:

```javascript
test("issue-adopt renames a hand-written issue and puts it on the board", () => {
  const { d, statePath, bin } = appDir([
    { title: "Export CSV", number: 7, id: "I_7", projectItems: [] },
  ]);
  runBoard(d, bin, statePath, ["issue-adopt", "s03-export-csv", "7", "Export CSV"]);
  const s = JSON.parse(readFileSync(statePath, "utf8"));
  const issue = s.issues.find((i) => i.number === 7);
  assert.equal(issue.title, "[s03-export-csv] Export CSV");
  assert.equal(s.item_add_calls, 1);
});
```

  Note on the assertions: the stub's `project item-add` does not attach a `projectItems`
  entry, so `add_issue_to_project_backlog` takes its "no project item" warning branch and
  still exits 0. Assert the rename and the item-add call — not the resulting status.

- [ ] **Step 3: Run it and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | tail -12`

  Expected: FAIL — `issue-adopt renames a hand-written issue and puts it on the board`
  fails because `dm-board.sh` prints its usage line and exits 1 on the unknown subcommand.

- [ ] **Step 4: Implement `cmd_issue_adopt`**

  In `src/lib/dm-board.sh`, add the function immediately after `cmd_issue_create_us`:

```bash
# Adopt an Issue written by hand: rename to the driven convention, then board it.
cmd_issue_adopt() {
  local key="${1:-}" number="${2:-}" title="${3:-}"
  [ -n "$key" ] && [ -n "$number" ] && [ -n "$title" ] || {
    echo "usage: issue-adopt <issue-key> <issue-number> <title>" >&2
    return 1
  }
  dm_config_load
  local repo full_title url
  repo="$(dm_config_repo)"
  full_title="[${key}] ${title}"
  "$(gh_bin)" issue edit "$number" -R "$repo" --title "$full_title" >/dev/null
  url="https://github.com/${repo}/issues/${number}"
  add_issue_to_project_backlog "$url" "$key"
}
```

  Then wire the dispatch in `main()`, after the `issue-create-ticket` case:

```bash
    issue-adopt) shift; cmd_issue_adopt "$@" ;;
```

  and extend the usage string in the same `case`:

```bash
      echo "usage: dm-board.sh status-get|status-set|issue-create-us|issue-create-ticket|issue-adopt|require-ready|parent-sync ..." >&2
```

- [ ] **Step 5: Run the tests and verify they pass**

  Run: `node --test tests/*.mjs 2>&1 | tail -10`

  Expected: PASS — `75 pass, 0 fail`.

- [ ] **Step 6: Commit**

```bash
git add src/lib/dm-board.sh tests/fixtures/gh-stub.sh tests/board-parse.test.mjs
git commit -m "feat: add issue-adopt to board an existing hand-written issue"
```

---

### Task 5: Make `/dm-stories` reuse the mapped Issues

This is where the Issue conversion actually happens — after `/dm-init`, when `.dm/config.json` exists and `dm-board.sh` can run.

**Files:**
- Modify: `src/commands/dm-stories.md:27-31` (the "Board — parent US only" block)
- Test: `tests/commands.test.mjs`

**Interfaces:**
- Consumes: the `## Open issue mapping` table produced by Task 2, rows shaped `| #<N> | <title> | s<NN>-<slug> |`, and `issue-adopt` from Task 4.
- Produces: no new interface. The existing `issue-create-us` call is preserved for unmapped stories — the pre-existing test `stories creates parent US only` asserts it.

- [ ] **Step 1: Write the failing test**

  Append to `tests/commands.test.mjs`:

```javascript
test("stories adopts an issue mapped by onboarding.md, with confirmation", () => {
  const t = readFileSync("src/commands/dm-stories.md", "utf8");
  assert.match(t, /docs\/onboarding\.md/);
  assert.match(t, /issue-create-us/);
  assert.match(t, /issue-adopt/);
  assert.match(t, /confirm/i);
});
```

- [ ] **Step 2: Run it and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | tail -12`

  Expected: FAIL — 1 failure on `stories adopts an issue mapped by onboarding.md, with confirmation`, `/docs\/onboarding\.md/` not matching.

- [ ] **Step 3: Edit the board block in `src/commands/dm-stories.md`**

  Replace step 5 (lines 27-31) with:

```markdown
5. **Board — parent US only.** For each story id, create one parent Issue (status `backlog`). Do **not** create child tickets here:
   ```bash
   bash .dm/lib/dm-board.sh issue-create-us <story-id> "<title>" <body-file>
   ```
   Body file: short summary + acceptance criteria excerpt. Skip create if an Issue with title prefix `[<story-id>]` already exists.

   **Onboarded project.** If `docs/onboarding.md` exists, read its `## Open issue mapping` table before creating anything (the heading is a verbatim anchor). When a story id appears in that table, the Issue is already written by hand: do **not** create a second one. Ask the user, **one Issue at a time** (AskUserQuestion), whether to adopt it:
   - adopt → one call, which renames the Issue, adds it to the project and sets `backlog`:
     ```bash
     bash .dm/lib/dm-board.sh issue-adopt <story-id> <N> "<title>"
     ```
     Never use `status-set` for this: it resolves an existing **project item**, and a
     hand-written Issue is not on the board yet.
   - decline → leave the Issue untouched and create the parent Issue normally.

   Nothing is renamed or moved without that explicit per-Issue answer. Issues listed under `## Issues fermées (contexte)` are never touched.
```

- [ ] **Step 4: Run the tests and verify they pass**

  Run: `node --test tests/*.mjs 2>&1 | tail -10`

  Expected: PASS — `76 pass, 0 fail`.

- [ ] **Step 5: Commit**

```bash
git add src/commands/dm-stories.md tests/commands.test.mjs
git commit -m "feat: adopt hand-written issues mapped by onboarding.md"
```

---

### Task 6: Route `/dm-status` and `/dm-help` to `/dm-continue`

Without this, the new command is undiscoverable: `/dm-status` sends every un-framed repo to `/dm-prd`, including one full of existing code.

**Files:**
- Modify: `src/commands/dm-status.md:28`
- Modify: `src/commands/dm-help.md` (new block before `## Une fois par projet`, line 9)
- Test: `tests/commands.test.mjs`

**Interfaces:**
- Consumes: nothing. Both files are user-facing routing text.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

  Append to `tests/commands.test.mjs`:

```javascript
test("status and help route an existing project to dm-continue", () => {
  assert.match(readFileSync("src/commands/dm-status.md", "utf8"), /\/dm-continue/);
  assert.match(readFileSync("src/commands/dm-help.md", "utf8"), /\/dm-continue/);
});
```

- [ ] **Step 2: Run it and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | tail -12`

  Expected: FAIL — 1 failure on `status and help route an existing project to dm-continue`.

- [ ] **Step 3: Edit `src/commands/dm-status.md`**

  Replace line 28:

```markdown
If docs/ doesn't exist at all, the project hasn't started. Two cases: source files exist outside `docs/` **and** the git history holds more than one commit → the project predates driven, point to /dm-continue. Otherwise the repo is empty: point to /dm-prd.
```

- [ ] **Step 4: Edit `src/commands/dm-help.md`**

  Insert this block immediately before `## Une fois par projet` (line 9), leaving the 1-14 numbering untouched:

```markdown
## Projet existant (code déjà là)
0. /dm-continue          — baseline produit `docs/onboarding.md` + mapping des Issues déjà écrites, sans rien muter. Puis on reprend en 1.
```

- [ ] **Step 5: Run the tests and verify they pass**

  Run: `node --test tests/*.mjs 2>&1 | tail -10`

  Expected: PASS — `77 pass, 0 fail`.

- [ ] **Step 6: Commit**

```bash
git add src/commands/dm-status.md src/commands/dm-help.md tests/commands.test.mjs
git commit -m "feat: route existing projects to dm-continue from status and help"
```

---

### Task 7: Verify the build propagates the command, then document it

The Codex and Grok targets are generated from `src/commands/`. This task proves the new file survives the build before the user-facing docs claim it exists.

**Files:**
- Modify: `README.md` (the `## Pipeline` section and the `## Usage` block)
- Modify: `DOC.md` (the pipeline table and the command reference)
- Test: `tests/build-targets.test.mjs` (read only — no change expected)

**Interfaces:**
- Consumes: `src/commands/dm-continue.md` from Task 2 and `issue-adopt` from Task 4.
- Produces: nothing. Terminal task.

- [ ] **Step 1: Verify the build emits the command for every target**

```bash
node bin/dm-build.mjs --target codex --src ./src --out /tmp/dm-stg-codex
node bin/dm-build.mjs --target claude --src ./src --out /tmp/dm-stg-claude
find /tmp/dm-stg-codex /tmp/dm-stg-claude -name '*continue*'
```

  Expected: at least one hit per target (a Codex skill directory `dm-continue/SKILL.md`, and the Claude command `commands/dm-continue.md`). No build code change is needed — if this prints nothing, stop and investigate before touching the docs.

- [ ] **Step 2: Document the entry point in `README.md`**

  In `## Pipeline`, above the `### Framing — once per product` heading, add:

```markdown
### Existing project

`/dm-continue` — the code already runs and the Issues are already written. It records a
product baseline in `docs/onboarding.md` and proposes a mapping for the open Issues,
mutating nothing. Then the normal framing resumes at `/dm-prd` (brownfield mode).
```

  In `## Usage`, add above `/dm-prd`:

```
    # existing project (code already there):
    /dm-continue
```

- [ ] **Step 3: Document it in `DOC.md`**

  Add a row at the top of the pipeline step table:

```markdown
| Continue | `/dm-continue` | Existing project: product baseline + Issue mapping, mutates nothing | `docs/onboarding.md` |
```

  And a paragraph in the command reference:

```markdown
**/dm-continue** — the brownfield entry point. Read-only on the repo and on GitHub: it
writes `docs/onboarding.md` (what the app does, the shipped baseline, a proposed
`issue #N → sNN-slug` mapping) and nothing else. It cannot touch the board — `.dm/config.json`
does not exist before `/dm-init`. The mapping is applied later by `/dm-stories`, one
confirmation per Issue. Fail-closed both ways: empty repo → `/dm-prd`; `docs/prd.md`
already present → `/dm-status`.
```

- [ ] **Step 4: Run the full suite one last time**

  Run: `node --test tests/*.mjs 2>&1 | tail -10`

  Expected: PASS — `77 pass, 0 fail`.

- [ ] **Step 5: Commit**

```bash
git add README.md DOC.md
git commit -m "docs: document the dm-continue brownfield entry point"
```
