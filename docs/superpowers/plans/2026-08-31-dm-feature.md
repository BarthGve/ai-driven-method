# `/dm-feature` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/dm-feature <slug>` command that adds a feature to a product already shipped: it frames the feature, amends the PRD, appends stories to the existing backlog, and routes to `/dm-architect` or `/dm-research` based on a mechanical impact check.

**Architecture:** The command owns no new mechanism. It reuses `issue-create-us` (already idempotent on the `[<story-id>]` title prefix) and the `stories-reviewer` subagent. The only structural additions are a `## Amendements` section in the PRD template and a "shipped product" section in the `stories-review` skill — the existing eight checks compare stories to each other and to the PRD, never to what is already in production.

**Tech Stack:** Markdown command, template and skill files under `src/` (the canonical source), Node.js built-in test runner (`node --test tests/*.mjs`), zero external dependencies. `bin/dm-build.mjs` propagates `src/commands/` and `src/skills/` to the Claude / Codex / Grok targets.

**Spec:** `docs/superpowers/specs/2026-08-31-dm-feature-design.md`

## Global Constraints

- Edit **only** `src/` — `src/AGENTS.md` is the sole tracked source of workflow rules. Root `AGENTS.md` and `CLAUDE.md` are gitignored local-install artifacts.
- Do **not** apply the driven pipeline to this repository itself. Work on a branch, commit with `feat:` / `fix:` / `test:` prefixes, open a PR.
- Run the suite with `node --test tests/*.mjs` — the glob is required, `node --test tests/` fails with a directory argument.
- Baseline before starting: **80 tests pass, 0 fail**.
- `gh pr create` on this fork defaults to the **upstream** repo. Always pass `--repo BarthGve/ai-driven-method`.
- No build change: `bin/dm-build.mjs` iterates `src/commands/` and `src/skills/`.
- The architecture trigger is an **enumeration**, never a judgement call. Exact list, copied verbatim into the command: a new runtime dependency; an external service or provider (payment, mail, storage, AI…); a new persistence store or a schema migration; a new authentication or authorization surface; an asynchronous mechanism, background job or queue.
- `/dm-feature` **appends** to `docs/stories.md` and never rewrites it. Ids continue the existing `s<NN>-<slug>` sequence.
- The feature review writes `docs/reviews/features/<id>.md`. It must never write `docs/reviews/stories.md`, which `/dm-status` (step 1) and `/dm-research` (line 26) grep for `^Stories ready:`.

---

### Task 1: Add the amendment history to the PRD template

The template stops at `## Success criteria`. Without a section for it, every project's `/dm-feature` run invents its own structure, and the "living PRD" decision loses the traceability that justified it.

**Files:**
- Modify: `src/templates/prd.md` (append after line 39)
- Test: `tests/templates.test.mjs`

**Interfaces:**
- Produces: the heading `## Amendements` and the entry shape that Task 3 writes into. Task 3 depends on these exact strings.

- [ ] **Step 1: Write the failing test**

  Append to `tests/templates.test.mjs`:

```javascript
test("prd template carries an amendment history for post-v1 features", () => {
  const t = readFileSync("src/templates/prd.md", "utf8");
  assert.match(t, /## Amendements/);
  assert.match(t, /cimeti[eè]re/i);
  assert.match(t, /Stories :/);
});
```

- [ ] **Step 2: Run it and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: FAIL — `prd template carries an amendment history for post-v1 features`, `/## Amendements/` not matching.

- [ ] **Step 3: Append the section to `src/templates/prd.md`**

```markdown

## Amendements
<Une entrée par feature ajoutée après la v1, la plus récente en haut. Le corps du PRD ci-dessus décrit le produit tel qu'il est aujourd'hui ; cette section dit comment il y est arrivé.>

### <AAAA-MM-JJ> — v<version cible> — <slug>
**Entre dans le périmètre :** <ce que la feature ajoute, en une ou deux lignes>
**Sorti du cimetière ?** <non | oui — justification du revirement : ce qui a changé depuis la décision d'exclure>
**Stories :** <s07-…, s08-…>
```

- [ ] **Step 4: Run the test and verify it passes**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: PASS — `81 pass, 0 fail`.

- [ ] **Step 5: Commit**

```bash
git add src/templates/prd.md tests/templates.test.mjs
git commit -m "feat: add an amendment history section to the PRD template"
```

---

### Task 2: Teach `stories-review` to judge a feature against a shipped product

The skill's eight checks compare stories to the PRD perimeter and to each other. None of them can catch a feature that duplicates something already in production, or that depends on a story not yet shipped. The subagent `src/agents/stories-reviewer.md` is **not** modified: same read-only tools, same closing lines.

**Files:**
- Modify: `src/skills/stories-review/SKILL.md` (new section before `## Severity scale`)
- Test: `tests/commands.test.mjs`

**Interfaces:**
- Consumes: nothing.
- Produces: the review dimension Task 3 invokes. The closing contract is unchanged and still exactly `Max severity: <critical|major|minor|none>` and `Stories ready: <yes|no>`.

- [ ] **Step 1: Write the failing test**

  Append to `tests/commands.test.mjs`:

```javascript
test("stories-review judges a feature against the shipped product", () => {
  const t = readFileSync("src/skills/stories-review/SKILL.md", "utf8");
  assert.match(t, /shipped/i);
  assert.match(t, /duplicat/i);
  // the closing contract the reviewer agent depends on must not move
  assert.match(t, /Stories ready/);
});
```

- [ ] **Step 2: Run it and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: FAIL — `stories-review judges a feature against the shipped product`, `/duplicat/i` not matching.

- [ ] **Step 3: Add the section to `src/skills/stories-review/SKILL.md`**

  Insert immediately before `## Severity scale`:

```markdown
## Reviewing a feature added after v1

When the input is a single feature added to a product already in production
(`/dm-feature`), the eight checks above still apply, and three more are decisive.
The breakdown is no longer judged only against the PRD: it is judged against what
already runs.

9. **Duplication of shipped work** — the feature re-delivers a slice a `shipped`
   story already covers. The eight checks only compare stories to each other, so
   this is invisible to them. Read the board status of every existing story before
   judging. **critical** — the work is already paid for.
10. **Dependency on unshipped work** — the feature assumes a story that is not yet
    `shipped`. It is not automatically wrong, but it must be stated: the feature
    cannot ship before its dependency. Unstated → **major**.
11. **Contradiction with production behaviour** — the feature changes a behaviour
    users already rely on without saying so. A deliberate change is legitimate; a
    silent one is a regression waiting to be shipped. **critical** when the
    acceptance criteria contradict a shipped story's criteria without naming it.

Graveyard rule, adjusted: a feature **may** come out of the graveyard, but only
with the justification recorded in the PRD's `## Amendements` section. Coming out
of the graveyard with no recorded justification stays **critical**.
```

- [ ] **Step 4: Run the test and verify it passes**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: PASS — `82 pass, 0 fail`.

- [ ] **Step 5: Commit**

```bash
git add src/skills/stories-review/SKILL.md tests/commands.test.mjs
git commit -m "feat: review a post-v1 feature against the shipped product"
```

---

### Task 3: Write the `/dm-feature` command

**Files:**
- Create: `src/commands/dm-feature.md`
- Test: `tests/commands.test.mjs`

**Interfaces:**
- Consumes: `## Amendements` from Task 1, the review dimension from Task 2, and the existing `bash .dm/lib/dm-board.sh issue-create-us <story-id> "<title>" <body-file>`.
- Produces: `docs/reviews/features/<id>.md` and appended stories in `docs/stories.md`. Task 4 routes to this command.

- [ ] **Step 1: Write the failing tests**

  Append to `tests/commands.test.mjs`:

```javascript
test("feature amends the PRD and appends stories without rewriting them", () => {
  const t = readFileSync("src/commands/dm-feature.md", "utf8");
  assert.match(t, /## Amendements/);
  assert.match(t, /append/i);
  assert.doesNotMatch(t, /rewrite docs\/stories\.md/i);
  assert.match(t, /issue-create-us/);
});

test("feature gates architecture on an explicit enumeration", () => {
  const t = readFileSync("src/commands/dm-feature.md", "utf8");
  for (const trigger of [/runtime dependency/i, /provider/i, /migration/i, /authorization/i, /queue/i]) {
    assert.match(t, trigger);
  }
  assert.match(t, /\/dm-architect/);
  assert.match(t, /\/dm-research/);
});

test("feature review does not clobber the framing review signal", () => {
  const t = readFileSync("src/commands/dm-feature.md", "utf8");
  assert.match(t, /docs\/reviews\/features\//);
  assert.match(t, /stories-reviewer/);
  assert.doesNotMatch(t, /write .*docs\/reviews\/stories\.md/i);
});

test("feature is fail-closed without a PRD or a breakdown", () => {
  const t = readFileSync("src/commands/dm-feature.md", "utf8");
  assert.match(t, /STOP/);
  assert.match(t, /docs\/prd\.md/);
  assert.match(t, /docs\/stories\.md/);
});
```

- [ ] **Step 2: Run them and verify they fail**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: FAIL — 4 failures, one per new test, all from `ENOENT` on `src/commands/dm-feature.md`. (`all dv commands exist` still passes here: `dm-feature` joins the `required` array in Task 4.)

- [ ] **Step 3: Create `src/commands/dm-feature.md`**

```markdown
---
description: Add a feature to a shipped product — frame it, amend the PRD, append stories
argument-hint: <feature slug or short description>
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---
# dm-feature — A feature on a product that already ships

Target feature: $ARGUMENTS

The product is framed, built and released. This command adds to it. It writes no
application code: it frames, amends, splits, and hands back to the normal per-story
pipeline.

## Prerequisites (fail-closed)
- `docs/prd.md` must exist. Missing → STOP: "No PRD — run /dm-prd, or /dm-continue on an existing project."
- `docs/stories.md` must exist. Missing → STOP: "Product not split yet — run /dm-stories."

## Step 1 — Frame the feature (AskUserQuestion, one at a time)
1. Need: what problem, for whom, why now?
2. Perimeter: what the feature delivers, and what stays out of it.
3. Graveyard check: read the PRD's "Explicitly NOT replicated / Out of scope" list.
   If this feature was killed there, ask for the justification of the reversal —
   what changed since that decision. A feature may leave the graveyard; it may not
   leave it silently.

Fill nothing you have not validated with me.

## Step 2 — Architecture impact (mechanical, not a judgement call)
Walk this list point by point and record which ones the feature hits:

- a new **runtime dependency**;
- an external **service or provider** (payment, mail, storage, AI…);
- a new **persistence store**, or a schema **migration**;
- a new **authentication or authorization** surface;
- an **asynchronous** mechanism, background job or **queue**.

One or more hits → the feature goes through `/dm-architect` (new ADR) before
`/dm-plan`. No hit → straight to `/dm-research`. Record the answer in the
amendment entry; do not decide by feel.

## Step 3 — Amend the PRD
Update the body of `docs/prd.md` in place — the perimeter table gains the feature,
the graveyard loses it if it came out — then add an entry at the top of the
`## Amendements` section:

    ### <AAAA-MM-JJ> — v<version cible> — <slug>
    **Entre dans le périmètre :** …
    **Sorti du cimetière ?** non | oui — <justification>
    **Stories :** <ids>

If `## Amendements` is absent (project framed before the template gained it),
create the section at the end of the file.

## Step 4 — Split into stories, and APPEND
Apply the `agentic-stories` skill: end-to-end shippable slices, testable acceptance
criteria, agentic notes, complexity 1-5 (a 5 gets split now).

Read the highest `s<NN>` already present in `docs/stories.md` and continue the
sequence. Ids name every pipeline file and every branch: a collision breaks the
whole cycle.

**Append** the new stories to `docs/stories.md`. Never rewrite the file — the
stories already there are shipped work, and their ids are referenced by
`docs/research/`, `docs/plans/`, `docs/reviews/` and by live branches.

## Step 5 — Parent Issues
One parent Issue per new story, status `backlog`, with the call that already
exists and is idempotent on the `[<story-id>]` title prefix:

```bash
bash .dm/lib/dm-board.sh issue-create-us <story-id> "<title>" <body-file>
```

## Step 6 — Fresh-context review
Delegate to the `stories-reviewer` subagent (read-only, fresh eyes — the context
that writes never reviews itself):

- prompt: Review the new feature stories against docs/prd.md (including its
  `## Amendements` section) and against the stories already shipped. The
  stories-review skill is preloaded; apply its "Reviewing a feature added after
  v1" section — duplication of shipped work, dependency on unshipped work,
  contradiction with production behaviour — on top of the eight standard checks.
  End with the exact lines "Max severity: <critical|major|minor|none>" and
  "Stories ready: <yes|no>".

Write the report to `docs/reviews/features/<id>.md`.

**Never write `docs/reviews/stories.md`.** That file is the product-level framing
signal: `/dm-status` and `/dm-research` grep it for `^Stories ready:`, and
overwriting it would report the whole breakdown as re-reviewed when it was not.

Soft gate, like the framing review: surfaced by `/dm-status`, not a hard block.

## Step 7 — Commit
Commit on the integration line — `next` once /dm-init has run, otherwise the
current default branch — with the message `docs: feature <slug>`.

End with, depending on Step 2:
- architecture touched → "Feature framed (<ids>). Next step: /dm-architect"
- otherwise → "Feature framed (<ids>). Next step: /dm-research <story-id>"
```

- [ ] **Step 4: Run the tests and verify they pass**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: PASS — `86 pass, 0 fail`.

- [ ] **Step 5: Commit**

```bash
git add src/commands/dm-feature.md tests/commands.test.mjs
git commit -m "feat: add dm-feature for a feature on a shipped product"
```

---

### Task 4: Register and route `/dm-feature`

Without this the command is undiscoverable: after a release every story is `shipped` and `/dm-status`'s "next command" logic has nothing left to propose.

**Files:**
- Modify: `tests/commands.test.mjs:5-10` (the `required` array)
- Modify: `src/commands/dm-status.md:25` (step 4, the next-command line)
- Modify: `src/commands/dm-help.md` (new block after the release section)

**Interfaces:**
- Consumes: `src/commands/dm-feature.md` from Task 3.
- Produces: nothing. Terminal task before docs.

- [ ] **Step 1: Add `dm-feature` to the required array and write the routing test**

  In `tests/commands.test.mjs`, the `required` array becomes:

```javascript
const required = [
  "dm-prd", "dm-init", "dm-stories", "dm-stories-review", "dm-architect",
  "dm-design-system", "dm-research", "dm-design", "dm-plan", "dm-docs",
  "dm-execute", "dm-review", "dm-ship", "dm-release", "dm-orchestrator",
  "dm-status", "dm-help", "dm-continue", "dm-feature",
];
```

  And append:

```javascript
test("status and help route a fully shipped product to dm-feature", () => {
  assert.match(readFileSync("src/commands/dm-status.md", "utf8"), /\/dm-feature/);
  assert.match(readFileSync("src/commands/dm-help.md", "utf8"), /\/dm-feature/);
});
```

- [ ] **Step 2: Run it and verify it fails**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: FAIL — 1 failure on `status and help route a fully shipped product to dm-feature`. (`all dv commands exist` passes: Task 3 already created the file.)

- [ ] **Step 3: Edit `src/commands/dm-status.md`**

  Replace step 4's last sentence so the line reads:

```markdown
4. Start with one-line summary: X shipped / Y in test / Z in progress / W backlog. Compact tables: US row, then indented ticket rows. Next command is the most useful one (often "move t02 to ready" or `/dm-execute s01 t01` or `/dm-release`). When every story is `shipped` and nothing is in flight, the product is released and the useful next command is `/dm-feature <slug>` — say so rather than reporting an empty pipeline.
```

- [ ] **Step 4: Edit `src/commands/dm-help.md`**

  Add after the `## Release (production)` block:

```markdown
## Après la v1 (produit livré)
15. /dm-feature <slug>   — cadre une feature, amende le PRD (section `## Amendements`), ajoute les stories au backlog. Puis pipeline normal : `/dm-architect` si la feature touche l'architecture, sinon `/dm-research <story>`.
```

- [ ] **Step 5: Run the tests and verify they pass**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (pass|fail)"`

  Expected: PASS — `87 pass, 0 fail`.

- [ ] **Step 6: Commit**

```bash
git add tests/commands.test.mjs src/commands/dm-status.md src/commands/dm-help.md
git commit -m "feat: route a shipped product to dm-feature from status and help"
```

---

### Task 5: Verify the build, then document

**Files:**
- Modify: `README.md` (`## Pipeline` and `## Usage`)
- Modify: `DOC.md` (step table and command reference)

**Interfaces:**
- Consumes: `src/commands/dm-feature.md` from Task 3.
- Produces: nothing. Terminal task.

- [ ] **Step 1: Verify the build emits the command and the amended skill**

```bash
rm -rf /tmp/dm-stg-feat
node bin/dm-build.mjs --target codex --src ./src --out /tmp/dm-stg-feat
find /tmp/dm-stg-feat -name '*feature*'
grep -c "Reviewing a feature added after v1" /tmp/dm-stg-feat/skills/stories-review/SKILL.md
```

  Expected: the find prints a `dm-feature` skill directory; the grep prints `1`. If either is empty, stop and investigate before touching the docs.

- [ ] **Step 2: Document in `README.md`**

  In `## Pipeline`, after the `### Production` block:

```markdown
### After v1

`/dm-feature <slug>` — the product ships and a new feature arrives. It frames the
feature, amends the PRD (living document: the perimeter is updated and the change
recorded under `## Amendements`), and appends stories to the existing backlog. A
mechanical impact list decides whether it goes through `/dm-architect` first.
```

  In `## Usage`, after `/dm-release`:

```
    # after v1, a new feature:
    /dm-feature <slug>
```

- [ ] **Step 3: Document in `DOC.md`**

  Add a row at the end of the pipeline step table:

```markdown
| Feature | `/dm-feature <slug>` | Post-v1: frame, amend the PRD, append stories | `docs/prd.md` + `docs/stories.md` |
```

  And a paragraph in the command reference, after the `/dm-release` one:

```markdown
**/dm-feature** — a feature on a product that already ships. The PRD is a living
document: the perimeter table is updated in place and the change is recorded under
`## Amendements` (date, target version, what enters the perimeter, and — when the
feature comes out of the graveyard — the justification for the reversal). Stories
are **appended** to `docs/stories.md`, ids continuing the existing sequence; the
file is never rewritten, since the ids already there are referenced by research,
plans, reviews and live branches. Architecture impact is decided by an
enumeration, not by feel: a new runtime dependency, an external service or
provider, a new persistence store or migration, a new auth surface, or an async
mechanism sends the feature through `/dm-architect` and a new ADR before
`/dm-plan`. The fresh-context review runs on `docs/reviews/features/<id>.md` and
never touches `docs/reviews/stories.md`, which carries the product-level
`Stories ready:` signal.
```

- [ ] **Step 4: Run the full suite**

  Run: `node --test tests/*.mjs 2>&1 | grep -E "^✖ |ℹ (tests|pass|fail)"`

  Expected: PASS — `87 pass, 0 fail`.

- [ ] **Step 5: Commit**

```bash
git add README.md DOC.md
git commit -m "docs: document the dm-feature post-v1 entry point"
```
