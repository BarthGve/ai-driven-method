# driven method Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish **driven** as a GitHub fork of `MikeCodeur/killer-saas` with the approved pipeline (hybrid PRD, Grok install, GitHub board/wiki, `main`/`next`, quality bar, semver release) so a user can `curl | bash` the tooling into an app repo.

**Architecture:** Keep killer-saas anatomy (canonical `src/`, `install.sh`, Node build, file gates, subagents). Rebrand `ks-*` → `dm-*`. Add `src/lib/*.sh` for mechanical GitHub operations (board, init, version, wiki) so commands call scripts instead of improvising `gh`. Emit Claude, Codex, and Grok from one source.

**Tech Stack:** Bash installer, Node.js (zero-dependency `bin/dm-build.mjs` + `node:test`), GitHub CLI `gh` (Projects V2, Issues, wiki git remote), git worktrees, GitHub Actions template for the *application* repo.

## Global Constraints

- Publish as a **GitHub fork** of `MikeCodeur/killer-saas`; keep history; `upstream` = original; do not detach the fork.
- Credit Mike Codeur in README, DOC.md, NOTICE; `install.sh` clones **this fork**, not upstream.
- Upstream has **no LICENSE**; do not relicense original files.
- Command prefix `/dm-*`. English commands/skills/templates/`AGENTS.md`; `/dm-help` in French.
- Install targets: `claude` | `codex` | `grok` | `all`.
- App git: `main` (prod, only from `next`) · `next` (integration) · `feature/<story-id>` (US docs) · `feature/<story-id>/<ticket-id>` (one child ticket) · worktrees `.worktrees/<story-id>` and `.worktrees/<story-id>/<ticket-id>`.
- Board: parent US Issue + child ticket Issues. Columns: `backlog` · `ready` · `in progress` · `test` · `shipped`. User alone moves **children** to `ready`. Parent never uses `ready`; parent `test` when all children are on `next`.
- Every child ticket has a required **size** (`XS`·`S`·`M`·`L`·`XL`) and **person-day** estimate (multiples of 0.5) in the plan and on the Issue; parent total days = sum; `/dm-status` shows remaining (children not yet `test`/`shipped`). No actuals in V1.
- Shipped + wiki + VERSION bump only on `/dm-release` (`next` → `main`). Wiki is one page per US, not per ticket.
- Quality: critical **or** major → `Ship allowed: no`.
- Manifest names: `.dm-manifest`, `.dm-version`, hooks path `.dm-hooks`.
- Authenticated GitHub user for the fork: `BarthGve`. Fork name: `ai-driven-method`.
- Spec: `docs/superpowers/specs/2026-08-29-driven-method-design.md`.

## File map

| Path | Responsibility |
| --- | --- |
| `NOTICE` | Attribution; fork relationship; IP-zone note |
| `README.md` / `DOC.md` | Credit + driven pipeline |
| `install.sh` | Install/update/init/hooks; clone URL = fork |
| `bin/dm-build.mjs` | Emit claude / codex / grok from `src/` |
| `src/AGENTS.md` | Repo law for the **app** after install |
| `src/commands/dm-*.md` | Pipeline commands (renamed + new init/docs/release) |
| `src/agents/*.md` | implementer, reviewer, stories-reviewer, worktree-manager |
| `src/skills/*/SKILL.md` | Know-how including `quality-bar` |
| `src/templates/*` | Including `product-doc.md` |
| `src/hooks/dm-gate.sh` | plan / ship / ready / branch gates |
| `src/lib/dm-board.sh` | Issue + Project status |
| `src/lib/dm-init.sh` | Repo, branches, protection, project, wiki, VERSION |
| `src/lib/dm-wiki.sh` | Publish `docs/product` to wiki on release |
| `src/lib/dm-version.sh` | Semver bump + changelog + tag |
| `src/workflows/dm-gate.yml` | Copied into the app at `/dm-init` |
| `tests/*.test.mjs` | `node:test` for build, gate, version, board helpers |
| `.dm/config.json` | **Not in the method repo** — created in the app by `/dm-init` |

---

### Task 1: Fork killer-saas and graft this spec onto its history

**Files:**
- Create (on GitHub): `BarthGve/ai-driven-method` as fork of `MikeCodeur/killer-saas`
- Keep: `docs/superpowers/specs/2026-08-29-driven-method-design.md`, this plan, `.gitignore`

**Interfaces:**
- Consumes: local spec commits on unrelated `main`
- Produces: `origin` → `git@github.com:BarthGve/ai-driven-method.git` (or HTTPS), `upstream` → `https://github.com/MikeCodeur/killer-saas.git`, `main` based on killer-saas history, spec files on top

- [ ] **Step 1: Write the failing check script**

Create `tests/fork-identity.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
git remote get-url upstream | grep -q 'MikeCodeur/killer-saas'
git remote get-url origin | grep -q 'ai-driven-method'
git merge-base --is-ancestor e2b857848285b793f39091b1eb9b2b1ce15a5e87 HEAD \
  || git merge-base --is-ancestor origin/main HEAD
test -f docs/superpowers/specs/2026-08-29-driven-method-design.md
test -f src/commands/ks-prd.md -o -f src/commands/dm-prd.md
echo OK
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x tests/fork-identity.sh
bash tests/fork-identity.sh
```

Expected: FAIL (`upstream` missing and/or no `src/commands`).

- [ ] **Step 3: Fork, fetch, graft spec**

```bash
SPEC_DIR=$(mktemp -d)
cp -R docs "$SPEC_DIR/docs"
cp .gitignore "$SPEC_DIR/" 2>/dev/null || true
test -f docs/superpowers/plans/2026-08-29-driven-method.md && \
  mkdir -p "$SPEC_DIR/docs/superpowers/plans" && \
  cp docs/superpowers/plans/2026-08-29-driven-method.md "$SPEC_DIR/docs/superpowers/plans/"

gh repo fork MikeCodeur/killer-saas --fork-name ai-driven-method --remote=false --clone=false

git remote add upstream https://github.com/MikeCodeur/killer-saas.git
git fetch upstream
git remote add origin "https://github.com/BarthGve/ai-driven-method.git"
git fetch origin

git checkout -B main origin/main
mkdir -p docs/superpowers/specs docs/superpowers/plans
cp -R "$SPEC_DIR/docs/." docs/
# restore .gitignore entries we need without dropping upstream's
grep -q .DS_Store .gitignore || echo .DS_Store >> .gitignore
```

If `gh repo fork` errors because `ai-driven-method` already exists, use that existing fork; do not create a non-fork duplicate.

- [ ] **Step 4: Run the check**

```bash
bash tests/fork-identity.sh
```

Expected: `OK`. `git log` shows killer-saas commits plus our spec. GitHub UI shows BarthGve/ai-driven-method **forked from** MikeCodeur/killer-saas.

- [ ] **Step 5: Commit (local) and push only after user agrees to publish**

```bash
git add docs tests/fork-identity.sh .gitignore
git commit -m "docs: graft driven spec onto killer-saas fork history"
```

Do not `git push -u origin main` until the user confirms they want the fork updated on GitHub.

---

### Task 2: Attribution (NOTICE + README + DOC.md)

**Files:**
- Create: `NOTICE`
- Modify: `README.md` (top), `DOC.md` (top)

**Interfaces:**
- Consumes: fork from Task 1
- Produces: credit block; `NOTICE` text below

- [ ] **Step 1: Write the failing test**

`tests/attribution.test.mjs`:

```javascript
import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

test("NOTICE credits Mike Codeur and the fork", () => {
  const t = readFileSync("NOTICE", "utf8");
  assert.match(t, /Mike Codeur|MikeCodeur/);
  assert.match(t, /killer-saas/);
  assert.match(t, /fork/i);
});

test("README credits upstream and names driven", () => {
  const t = readFileSync("README.md", "utf8");
  assert.match(t, /https:\/\/github.com\/MikeCodeur\/killer-saas/);
  assert.match(t, /ai-driven-method/);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node --test tests/attribution.test.mjs
```

Expected: FAIL (`NOTICE` missing).

- [ ] **Step 3: Write NOTICE and credit headers**

`NOTICE`:

```
driven is a fork of killer-saas
https://github.com/MikeCodeur/killer-saas
Original method: Mike Codeur (MikeCodeur)

This repository keeps git history and the GitHub fork relationship.
Upstream, at the time of the fork, had no LICENSE file. Files inherited
from killer-saas are not relicensed here.

Zones marked "<< IP Mike >>" in upstream were empty placeholders.
Heuristics and commands added in driven are fork additions.

Material changes in driven vs killer-saas:
- hybrid PRD (clone a SaaS or greenfield)
- install target for Grok in addition to Claude Code and Codex
- GitHub Project board with ready-gate
- product wiki publish on release
- main / next git flow
- quality bar that blocks ship on major findings
- semver bump on next → main
```

Prepend README:

```markdown
# ai-driven-method

A fork of [killer-saas](https://github.com/MikeCodeur/killer-saas) by [Mike Codeur](https://github.com/MikeCodeur).

Commands: `/dm-*`.

driven keeps the original pipeline (no direct coding, file gates, subagents)
and adds: hybrid PRD (clone or greenfield), Grok install, GitHub board + wiki,
`main`/`next` flow, a stricter quality bar, and semver on release.

See [NOTICE](NOTICE) and [DOC.md](DOC.md).
```

Prepend DOC.md with the same credit paragraph (do not delete the inherited method docs; retitle later in Task 3).

- [ ] **Step 4: Run tests**

```bash
node --test tests/attribution.test.mjs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add NOTICE README.md DOC.md tests/attribution.test.mjs
git commit -m "docs: credit Mike Codeur and killer-saas as the upstream fork"
```

---

### Task 3: Rebrand tooling `ks` → `dv` and `killer-saas` → `driven`

**Files:**
- Rename: `bin/ks-build.mjs` → `bin/dm-build.mjs`
- Rename: `src/commands/ks-*.md` → `src/commands/dm-*.md`
- Rename: `src/hooks/ks-gate.sh` → `src/hooks/dm-gate.sh`
- Modify: `install.sh`, `bin/dm-build.mjs`, `src/AGENTS.md`, `src/commands/*.md`, `src/hooks/*`, `README.md`, `DOC.md`
- Test: `tests/rebrand.test.mjs`

**Interfaces:**
- Consumes: Claude-shaped `src/`
- Produces: commands named `dm-*`; installer dest `.dm-manifest` / `.dm-version` / `.dm-hooks`; `REPO=https://github.com/BarthGve/ai-driven-method.git`; CACHE `$HOME/.claude/ai-driven-method`

- [ ] **Step 1: Write the failing test**

```javascript
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";

test("command files are dm- prefixed", () => {
  const names = readdirSync("src/commands").filter((f) => f.endsWith(".md"));
  assert.ok(names.length >= 13);
  for (const n of names) assert.match(n, /^dm-/);
});

test("install.sh points at the fork and dv paths", () => {
  const t = readFileSync("install.sh", "utf8");
  assert.match(t, /BarthGve\/ai-driven-method/);
  assert.match(t, /\.dm-manifest/);
  assert.doesNotMatch(t, /MikeCodeur\/killer-saas\.git/);
  assert.doesNotMatch(t, /\.ks-manifest/);
});

test("dm-build emits claude command dm-prd", () => {
  const out = mkdtempSync(join(tmpdir(), "dm-build-"));
  execFileSync("node", ["bin/dm-build.mjs", "--target", "claude", "--src", "src", "--out", out]);
  assert.ok(existsSync(join(out, "commands", "dm-prd.md")));
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node --test tests/rebrand.test.mjs
```

Expected: FAIL (files still `ks-*`).

- [ ] **Step 3: Rebrand**

```bash
git mv bin/ks-build.mjs bin/dm-build.mjs
git mv src/hooks/ks-gate.sh src/hooks/dm-gate.sh
for f in src/commands/ks-*.md; do git mv "$f" "${f/ks-/dm-}"; done
```

Replace in all tracked text files (python/perl is fine):

- `killer-saas` → `driven` (except credit URLs to `MikeCodeur/killer-saas` and NOTICE)
- `/ks-` → `/dm-`
- `ks-prd` etc. inside bodies → `dm-`
- `.ks-manifest` → `.dm-manifest`
- `.ks-version` → `.dm-version`
- `.ks-hooks` → `.dm-hooks`
- `ks-gate` → `dm-gate`
- `ks-build` → `dm-build`
- `~/.claude/killer-saas` → `~/.claude/ai-driven-method`
- `REPO="https://github.com/MikeCodeur/killer-saas.git"` → `REPO="https://github.com/BarthGve/ai-driven-method.git"`

In `src/hooks/pre-commit` and `pre-push`, exec `dm-gate.sh`.

In `bin/dm-build.mjs`, keep Claude/Codex emission; command names come from filenames so they become `dm-*` automatically.

Do **not** replace the credit link `https://github.com/MikeCodeur/killer-saas` in NOTICE/README/DOC attribution blocks.

- [ ] **Step 4: Run tests**

```bash
node --test tests/rebrand.test.mjs tests/attribution.test.mjs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: rebrand killer-saas tooling to driven (/dm-*)"
```

---

### Task 4: Grok install target

**Files:**
- Modify: `bin/dm-build.mjs` (add `emitGrok`)
- Modify: `install.sh` (`TARGET` includes `grok`; `copy_tooling_grok`; `all` = claude+codex+grok)
- Test: `tests/build-targets.test.mjs`

**Interfaces:**
- Consumes: `dm-build.mjs --target claude|codex`
- Produces: `--target grok` writes `commands/*.md`, `skills/*/`, `agents/*.md` under `--out` (same layout as Claude, destined for `.grok/`)

- [ ] **Step 1: Write the failing test**

```javascript
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";

function emit(target) {
  const out = mkdtempSync(join(tmpdir(), `dm-${target}-`));
  execFileSync("node", ["bin/dm-build.mjs", "--target", target, "--src", "src", "--out", out]);
  return out;
}

test("grok emit has commands, skills, agents", () => {
  const out = emit("grok");
  assert.ok(existsSync(join(out, "commands", "dm-prd.md")));
  assert.ok(existsSync(join(out, "skills", "tdd-skill", "SKILL.md")));
  assert.ok(existsSync(join(out, "agents", "implementer.md")));
});

test("codex emit still puts commands in skills/", () => {
  const out = emit("codex");
  assert.ok(existsSync(join(out, "skills", "dm-prd", "SKILL.md")));
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node --test tests/build-targets.test.mjs
```

Expected: FAIL (`unknown target: grok`).

- [ ] **Step 3: Implement emitGrok + installer**

In `bin/dm-build.mjs`, Grok emission is the Claude tree (commands + skills + agents copied). Accept `grok` in `main`.

In `install.sh`:

```bash
copy_tooling_grok() {
  local dest="$1" stg
  command -v node >/dev/null 2>&1 || { echo "✗ Node required for grok target." >&2; return 1; }
  stg="$(mktemp -d)"
  node "$PAYLOAD_ROOT/bin/dm-build.mjs" --target grok --src "$SRC" --out "$stg" >/dev/null
  clean_tooling "$dest"
  mkdir -p "$dest/commands" "$dest/skills" "$dest/agents"
  cp -R "$stg/commands/." "$dest/commands/"
  cp -R "$stg/skills/."   "$dest/skills/"
  cp -R "$stg/agents/."   "$dest/agents/"
  : > "$dest/.dm-manifest"
  for f in "$dest/commands/"*.md; do echo "commands/$(basename "$f")" >> "$dest/.dm-manifest"; done
  for f in "$dest/skills/"*/;     do echo "skills/$(basename "$f")"   >> "$dest/.dm-manifest"; done
  for f in "$dest/agents/"*.md;   do echo "agents/$(basename "$f")"   >> "$dest/.dm-manifest"; done
  echo "$VERSION" > "$dest/.dm-version"
  rm -rf "$stg"
}
```

`install_target grok` → `copy_tooling_grok "./.grok"` then `sync_templates` + `drop_agents_md` (no CLAUDE.md required). `--target all` runs claude, codex, grok. Global grok dest: `$HOME/.grok`.

Update README install examples with `--target grok` and `--target all`.

- [ ] **Step 4: Run tests**

```bash
node --test tests/build-targets.test.mjs tests/rebrand.test.mjs
```

Expected: PASS. Manual smoke:

```bash
TMP=$(mktemp -d) && cd "$TMP" && git init && \
  bash /path/to/driven/install.sh --target grok
test -f .grok/commands/dm-prd.md && test -f AGENTS.md
```

- [ ] **Step 5: Commit**

```bash
git add bin/dm-build.mjs install.sh README.md tests/build-targets.test.mjs
git commit -m "feat: emit and install Grok target (.grok/commands, skills, agents)"
```

---

### Task 5: Hybrid PRD, stack advisor, filled heuristics

**Files:**
- Modify: `src/commands/dm-prd.md`, `src/templates/prd.md`
- Modify: `src/commands/dm-architect.md`
- Modify: `src/skills/agentic-stories/SKILL.md`, `codebase-analysis/SKILL.md`, `tdd-skill/SKILL.md`, `stories-review/SKILL.md`
- Test: `tests/templates.test.mjs`

**Interfaces:**
- Consumes: rebranded commands
- Produces: PRD template with `mode: clone | greenfield`; architect asks stack from PRD if repo empty

- [ ] **Step 1: Write the failing test**

```javascript
import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

test("prd template has hybrid mode", () => {
  const t = readFileSync("src/templates/prd.md", "utf8");
  assert.match(t, /greenfield/i);
  assert.match(t, /clone|Target SaaS/i);
  assert.doesNotMatch(t, /<< IP Mike/);
});

test("prd command asks clone vs greenfield first", () => {
  const t = readFileSync("src/commands/dm-prd.md", "utf8");
  assert.match(t, /greenfield/i);
});

test("skills have no empty IP placeholders", () => {
  for (const p of [
    "src/skills/agentic-stories/SKILL.md",
    "src/skills/codebase-analysis/SKILL.md",
    "src/skills/tdd-skill/SKILL.md",
    "src/skills/stories-review/SKILL.md",
  ]) {
    assert.doesNotMatch(readFileSync(p, "utf8"), /<< IP Mike/);
  }
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node --test tests/templates.test.mjs
```

Expected: FAIL (placeholders still present / no greenfield).

- [ ] **Step 3: Write content**

`src/templates/prd.md` — add after title:

```markdown
## Mode
<clone | greenfield>

## Target SaaS
<clone only: name, URL, one-line; greenfield: "n/a — original product">
```

Keep perimeter / graveyard / angle for **both** modes (greenfield uses in/out of scope). Kill mode section: clone only; greenfield writes `n/a`.

`dm-prd.md` step 1: AskUserQuestion — Clone existing SaaS vs greenfield. Then the matching question set from the spec §11 `/dm-prd`.

`dm-architect.md`: if no boilerplate, AskUserQuestion is **not** hardcoded ship-saas.now vs Next. Propose 2–3 stacks from the PRD (clone target tech, data/auth/realtime needs, team constraints) plus “blank repo, record ADRs only”. Scaffold only after confirmation.

Replace each `<< IP Mike >>` with:

**agentic-stories:** one story = one user-valuable slice; max ~10 plan tasks; complexity 5 must split; criteria must be falsifiable; ids `s<number>-<slug>`; clone mode may cite the target screen in notes; never graveyard items.

**codebase-analysis:** breadth-first map then one vertical slice; conventions as rules not observations; if empty repo, recommend stack from PRD constraints (language already in repo wins).

**tdd-skill:** keep existing bite/mutation rules; add: project test command is discovered from package.json/pyproject/Makefile; never assert CSS class names; max two new test files per story.

**stories-review:** coverage walk from PRD table; graveyard leak = critical; unsplit 5 = major.

Strip `<< IP Mike >>` from templates too.

- [ ] **Step 4: Run tests**

```bash
node --test tests/templates.test.mjs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/commands/dm-prd.md src/commands/dm-architect.md src/templates src/skills tests/templates.test.mjs
git commit -m "feat: hybrid PRD, stack advisor, and filled story/TDD heuristics"
```

---

### Task 6: Quality bar (blocks major) and reviewer wiring

**Files:**
- Create: `src/skills/quality-bar/SKILL.md`
- Modify: `src/agents/implementer.md`, `src/agents/reviewer.md`
- Modify: `src/templates/review-checklist.md`
- Modify: `src/commands/dm-review.md`
- Remove or stop preloading: `src/skills/review-antihallu` (fold into quality-bar; delete skill dir after moving content)
- Test: `tests/quality-bar.test.mjs`

**Interfaces:**
- Consumes: reviewer report lines `Max severity:` and `Ship allowed:`
- Produces: skill `quality-bar`; `Ship allowed: no` if max severity is `critical` **or** `major`

- [ ] **Step 1: Write the failing test**

```javascript
import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

test("quality-bar skill exists and blocks major", () => {
  const t = readFileSync("src/skills/quality-bar/SKILL.md", "utf8");
  assert.match(t, /major/);
  assert.match(t, /Ship allowed: no/);
  assert.match(t, /security/i);
  assert.match(t, /factori[sz]ation|duplicat/i);
});

test("reviewer preloads quality-bar", () => {
  const t = readFileSync("src/agents/reviewer.md", "utf8");
  assert.match(t, /quality-bar/);
});

test("review checklist includes security and factorization", () => {
  const t = readFileSync("src/templates/review-checklist.md", "utf8");
  assert.match(t, /Security/i);
  assert.match(t, /Factor/i);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node --test tests/quality-bar.test.mjs
```

Expected: FAIL (skill missing).

- [ ] **Step 3: Implement skill + checklist**

`quality-bar/SKILL.md` must include: anti-hallucination procedure (from review-antihallu), OWASP-on-diff (injection, authz, secrets, IDOR, XSS, sensitive logs), one-rule-one-place, no speculative abstraction, bite mutation, severity:

- critical: security hole, leak, invented API, untested/duplicated business rule, regression
- major: copy-paste of existing flow, unevolvable module, plan ignored, visual-system break — **also `Ship allowed: no`**
- minor: style — ship allowed

`reviewer.md` `skills: [quality-bar]`. `implementer.md` skills: `tdd-skill` and `quality-bar`.

Reviewer + `dm-review.md`: “A single critical **or major** = no.”

- [ ] **Step 4: Run tests**

```bash
node --test tests/quality-bar.test.mjs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/skills/quality-bar src/skills/review-antihallu src/agents src/templates/review-checklist.md src/commands/dm-review.md tests/quality-bar.test.mjs
git commit -m "feat: quality-bar skill blocks ship on major and critical findings"
```

---

### Task 7: App git flow `next` / `main` and ship target

**Files:**
- Modify: `src/AGENTS.md` (branches, Quick Fix on `next`, ship strategy → `next`)
- Modify: `src/commands/dm-ship.md` (PR base `next`)
- Modify: `src/commands/dm-research.md` / `worktree-manager.md` (branch from `next`)
- Modify: `src/hooks/dm-gate.sh` (pre-push: refuse non-next into `main`)
- Test: `tests/gate.test.mjs` spawning `dm-gate.sh`

**Interfaces:**
- Consumes: `dm-gate.sh plan-validated|ship-allowed|pre-commit|pre-push`
- Produces: `dm-gate.sh default-integration-branch` prints `next`; worktree created from `next`

- [ ] **Step 1: Write failing gate tests**

Use a temp git repo fixture in the test (init, branches `main` and `next`, file `docs/reviews/s01-x.md` with `Ship allowed: yes`).

```javascript
import { execFileSync, execSync } from "node:child_process";
import { mkdtempSync, writeFileSync, mkdirSync, chmodSync, cpSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const GATE = join(dirname(fileURLToPath(import.meta.url)), "..", "src/hooks/dm-gate.sh");

function repo() {
  const d = mkdtempSync(join(tmpdir(), "dm-gate-"));
  execSync("git init -b main && git config user.email t@t && git config user.name t", { cwd: d });
  writeFileSync(join(d, "README"), "x");
  execSync("git add README && git commit -m i", { cwd: d });
  execSync("git branch next", { cwd: d });
  return d;
}

test("plan-validated fails without file", () => {
  const d = repo();
  chmodSync(GATE, 0o755);
  assert.throws(() => execFileSync("bash", [GATE, "plan-validated", "s01-x"], { cwd: d, stdio: "pipe" }));
});
```

Add a test that `AGENTS.md` mentions `next` as integration and Quick Fix on `next`.

- [ ] **Step 2: Run test to verify it fails**

```bash
node --test tests/gate.test.mjs
```

Expected: FAIL or AGENTS still says default-branch / `dev`.

- [ ] **Step 3: Update AGENTS, ship, worktree-manager, gate**

- Story framing branch from `next`: `git worktree add -b feature/<story-id> .worktrees/<story-id> next` (docs only).
- Ticket branch from `next`: `git worktree add -b feature/<story-id>/<ticket-id> .worktrees/<story-id>/<ticket-id> next`.
- `/dm-ship` PR base is `next`, **per ticket**. Cleanup that ticket worktree after `MERGED`. Parent US → `test` only when every child is `test` or `shipped`.
- Quick Fix: branch `next` (stop if not on `next`, ask; never auto-switch).
- `dm-gate.sh`: treat integration branch as `next`; default production branch `main`; pre-commit ready-gate looks up the **child** Issue from `feature/<story-id>/<ticket-id>`. Document that GitHub branch protection is the real guarantee for `main`.

- [ ] **Step 4: Run tests**

```bash
node --test tests/gate.test.mjs
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/AGENTS.md src/commands/dm-ship.md src/agents/worktree-manager.md src/hooks tests/gate.test.mjs
git commit -m "feat: integrate on next, protect main, Quick Fix on next"
```

---

### Task 8: Mechanical GitHub libs (board, init, version, wiki)

**Files:**
- Create: `src/lib/dm-config.sh`, `src/lib/dm-board.sh`, `src/lib/dm-init.sh`, `src/lib/dm-version.sh`, `src/lib/dm-wiki.sh`
- Create: `src/templates/product-doc.md`
- Test: `tests/version.test.mjs`, `tests/board-parse.test.mjs`

**Interfaces:**
- Consumes: `.dm/config.json` in the **app** (`owner`, `repo`, `project_id`, `status_field_id`, `status_option_ids` map)
- Produces:

```bash
dm-board.sh status-get <issue-key>                    # story-id or story-id/ticket-id
dm-board.sh status-set <issue-key> <status>
dm-board.sh issue-create-us <story-id> <title> <body-file>
dm-board.sh issue-create-ticket <story-id> <ticket-id> <title> <body-file>  # title (M, 1.5d); body Size + Estimate
dm-board.sh require-ready <story-id>/<ticket-id>      # child only; exit 1 if backlog/missing
dm-board.sh parent-sync <story-id>                    # derive parent column from children
dm-version.sh bump major|minor|patch
dm-version.sh current
dm-wiki.sh publish <app-root> <version> <story-id...>
dm-init.sh run   # --repo --public --yes
```

- [ ] **Step 1: Write failing tests for version bump (pure, no gh)**

```javascript
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, chmodSync, cpSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";

test("bump minor 0.1.0 -> 0.2.0", () => {
  const d = mkdtempSync(join(tmpdir(), "ver-"));
  writeFileSync(join(d, "VERSION"), "0.1.0\n");
  const script = join(process.cwd(), "src/lib/dm-version.sh");
  chmodSync(script, 0o755);
  const out = execFileSync("bash", [script, "bump", "minor"], { cwd: d, encoding: "utf8" }).trim();
  assert.equal(out, "0.2.0");
  assert.equal(readFileSync(join(d, "VERSION"), "utf8").trim(), "0.2.0");
});
```

Board parse test: a function `status_from_json` or fixture YAML reader — if `dm-board.sh` sources `dm-config.sh`, test `require-ready` with a stub `gh` on `PATH`.

Stub `gh`:

```bash
#!/bin/sh
# tests/fixtures/gh-stub.sh — echo canned JSON based on args
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
node --test tests/version.test.mjs
```

Expected: FAIL (script missing).

- [ ] **Step 3: Implement scripts**

`dm-version.sh`: read `VERSION`; bump; write; if `package.json` has `"version"`, bump it with `node -e` (no extra dep). Same for `pyproject.toml` `[project] version` via a small regex. Append `CHANGELOG.md` heading `## X.Y.Z - YYYY-MM-DD` if file exists.

`dm-config.sh`: `yq` is **not** required. Parse `.dm/config.json` with awk/python or keep JSON `.dm/config.json` if YAML parsing is painful — **use JSON** `.dm/config.json` to stay zero-dep (update spec implementer: file is JSON). Spec said YAML; **this plan locks JSON** `.dm/config.json` for grepable, jq-free node/python-free bash + Node:

```json
{
  "owner": "BarthGve",
  "repo": "my-app",
  "projectId": "PVT_kw...",
  "statusFieldId": "xxx",
  "status": {
    "backlog": "opt1",
    "ready": "opt2",
    "in progress": "opt3",
    "test": "opt4",
    "shipped": "opt5"
  }
}
```

If the spec file still says `.dm/config.json`, change it in the same commit to `.dm/config.json`.

`dm-board.sh`: `gh project item-edit` / GraphQL. Status labels **exactly** the five strings. `require-ready` is **child-only** and succeeds for `ready` and `in progress`. `parent-sync` sets parent to `in progress` if any child is, `test` if all children are `test`/`shipped`, `shipped` if all children are `shipped`.

`dm-init.sh`: `gh repo create`, `git branch next`, `gh api` branch protection (`required_pull_request_reviews`, restrict `main` merge from `next` via rulesets if classic protection cannot lock source branch — use **Repository rulesets** API: `main` allow only `next`; `next` allow `feature/*`). Create Project V2, create status field options, write `.dm/config.json`, enable wiki `gh api -X PATCH repos/{o}/{r} -f has_wiki=true`, write `VERSION` `0.1.0`. Flags `--yes` skip prompts for tests.

`dm-wiki.sh`: clone `https://github.com/{o}/{r}.wiki.git` into a temp dir (needs `GH_TOKEN`/`gh auth`), copy `docs/product/<id>.md` to wiki pages named `{id}.md`, rebuild `Home.md` with version and list of shipped ids, commit, push.

`src/templates/product-doc.md`: purpose, user flow, visible rules, out of scope.

- [ ] **Step 4: Run tests**

```bash
node --test tests/version.test.mjs tests/board-parse.test.mjs
```

Expected: PASS without network.

- [ ] **Step 5: Commit**

```bash
git add src/lib src/templates/product-doc.md tests/version.test.mjs tests/board-parse.test.mjs docs/superpowers/specs/2026-08-29-driven-method-design.md
git commit -m "feat: add board, init, version, and wiki helper scripts"
```

---

### Task 9: Commands `/dm-init`, `/dm-docs`, `/dm-release` + board wiring

**Files:**
- Create: `src/commands/dm-init.md`, `dm-docs.md`, `dm-release.md`
- Modify: `dm-stories.md`, `dm-research.md`, `dm-execute.md`, `dm-ship.md`, `dm-orchestrator.md`, `dm-status.md`, `dm-help.md`, `dm-plan.md`
- Modify: `src/workflows` — add `src/workflows/dm-gate.yml` (copied by init)
- Test: `tests/commands.test.mjs` (file presence + contract greps)

**Interfaces:**
- Consumes: `src/lib/*.sh`
- Produces: 16+ commands; stories create parent US; plan creates child tickets; execute/ship per child with `require-ready`; parent-sync to `test`/`shipped`; release wiki per US

- [ ] **Step 1: Write the failing test**

```javascript
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

const required = [
  "dm-prd", "dm-init", "dm-stories", "dm-stories-review", "dm-architect",
  "dm-design-system", "dm-research", "dm-design", "dm-plan", "dm-docs",
  "dm-execute", "dm-review", "dm-ship", "dm-release", "dm-orchestrator",
  "dm-status", "dm-help",
];

test("all dv commands exist", () => {
  for (const n of required) {
    assert.ok(existsSync(`src/commands/${n}.md`), n);
  }
});

test("stories creates parent US only", () => {
  assert.match(readFileSync("src/commands/dm-stories.md", "utf8"), /issue-create-us/);
});

test("plan creates child tickets with size and person-day estimates", () => {
  const t = readFileSync("src/commands/dm-plan.md", "utf8");
  assert.match(t, /issue-create-ticket/);
  assert.match(t, /estimate/i);
  assert.match(t, /size/i);
  assert.match(t, /XS|S|M|L|XL/);
  assert.match(t, /0\.5/);
});

test("research does not require ready", () => {
  assert.doesNotMatch(readFileSync("src/commands/dm-research.md", "utf8"), /require-ready/);
});

test("execute requires child ready", () => {
  assert.match(readFileSync("src/commands/dm-execute.md", "utf8"), /require-ready/);
});

test("ship sets test status", () => {
  assert.match(readFileSync("src/commands/dm-ship.md", "utf8"), /status-set .*test/);
});

test("release bumps version and wiki", () => {
  const t = readFileSync("src/commands/dm-release.md", "utf8");
  assert.match(t, /dm-version\.sh bump/);
  assert.match(t, /dm-wiki\.sh publish/);
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
node --test tests/commands.test.mjs
```

Expected: FAIL (new commands missing).

- [ ] **Step 3: Write commands**

`dm-init.md`: prereq `docs/prd.md`; AskUserQuestion create remote / name / public / org; then `bash src/lib/dm-init.sh` (after install the path is the copied lib — **installer must copy `src/lib` into `.dm/lib` or `templates` is not enough**). **Update `install.sh` in this task** to copy `src/lib` → `./.dm/lib` in the app (project files, like templates). Commands call `bash .dm/lib/dm-board.sh`.

`dm-docs.md`: prereq plan `validated: yes`; write `docs/product/<id>.md` from `@templates/product-doc.md`; no wiki push.

`dm-release.md`: list Issues in `test`; AskUserQuestion major/minor/patch with default minor; `dm-version.sh bump`; commit on `next`; `gh pr create --base main --head next`; after MERGED: tag `v$(cat VERSION)`, `dm-wiki.sh publish`, `status-set shipped` for each id in the release.

Wire:

- `dm-stories`: after writing `docs/stories.md`, for each US `dm-board.sh issue-create-us` (parent only)
- `dm-research` / `dm-design` / `dm-docs`: no `require-ready`
- `dm-plan`: on Validate, every ticket must have `size:` (XS–XL) and `estimate:` (0.5 steps); `issue-create-ticket` for each (children in `backlog`, size+estimate in title/body); parent body updated with sum of days and size mix
- `dm-execute`: `require-ready <story>/<ticket>` then `status-set in progress`
- `dm-ship`: require `docs/product/<story-id>.md`; PR `--base next`; after MERGED child `status-set test` then `parent-sync`
- `dm-release`: parent US in `test`; after merge parents + children `shipped`; wiki per US
- `dm-status`: parent and children via `status-get`
- `dm-help`: French map including US vs tickets, `ready` on children only
- `dm-orchestrator <story>`: research → design → plan (checkpoint) → docs, then list backlog tickets
- `dm-orchestrator <story> <ticket>`: execute → review → ship (checkpoint)

`src/workflows/dm-gate.yml`: on `pull_request` to `next` and `main`; steps: checkout, grep `Ship allowed: yes` when PR is `feature/*` → `next`; when PR is `next` → `main`, fail if `VERSION` unchanged vs base.

Installer `sync_lib()` copies `src/lib` to `.dm/lib` always (overwrite on update — these are tooling).

- [ ] **Step 4: Run tests**

```bash
node --test tests/commands.test.mjs tests/rebrand.test.mjs tests/build-targets.test.mjs
```

Expected: PASS. `install.sh --target grok` in a temp dir includes `.dm/lib/dm-board.sh`.

- [ ] **Step 5: Commit**

```bash
git add src/commands src/workflows src/lib install.sh tests/commands.test.mjs
git commit -m "feat: add init, docs, release commands and board lifecycle wiring"
```

---

### Task 10: Hooks ready-gate, installer docs, method README usage

**Files:**
- Modify: `src/hooks/dm-gate.sh` (`ready-ok` subcommand; pre-commit calls it)
- Modify: `README.md`, `DOC.md` (full driven pipeline, install one-liners with BarthGve/ai-driven-method)
- Test: extend `tests/gate.test.mjs` and `tests/fork-identity.sh` if needed

**Interfaces:**
- Consumes: `dm-board.sh status-get` (if `.dm/config.json` missing, pre-commit **warns** but does not block — board not initialized yet; after init, missing ready **blocks**)
- Produces: documented install; `curl -fsSL https://raw.githubusercontent.com/BarthGve/ai-driven-method/main/install.sh`

- [ ] **Step 1: Write failing test** — pre-commit on `feature/s01-x` with stub status `backlog` exits 1 when config exists.

- [ ] **Step 2: Run it** — expect FAIL.

- [ ] **Step 3: Implement `ready-ok`** in `dm-gate.sh`: if no `.dm/config.json`, return 0; else `status-get` must be `ready` or `in progress` for code commits on `feature/*`.

Rewrite README Usage:

```
/dm-prd
/dm-init
/dm-stories
...
/dm-release
```

DOC.md: replace killer framing with hybrid + board + wiki + version; keep philosophy of no direct coding; keep credit.

- [ ] **Step 4: Run full test suite**

```bash
node --test tests/*.test.mjs
bash tests/fork-identity.sh
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add src/hooks README.md DOC.md tests
git commit -m "feat: enforce board ready on pre-commit and document driven usage"
```

---

## Self-review (author)

| Spec section | Task |
| --- | --- |
| Fork + credit | 1, 2 |
| Rebrand + installer | 3 |
| Grok target | 4 |
| Hybrid PRD, stack advisor, heuristics | 5 |
| Quality bar | 6 |
| `main`/`next`, Quick Fix | 7 |
| Board/wiki/version/init scripts | 8 |
| Commands + lib copy + CI workflow | 9 |
| Ready hook + docs | 10 |
| `/dm-docs` before first child ship | 9 |
| US parent + child tickets, `ready` on children | 8, 9 |
| Size (XS–XL) and person-day estimates on tickets | 9 |
| Semver on release | 8, 9 |
| No Cursor/Gemini, no detach fork | honored (out of scope) |

Config path locked to `.dm/config.json` in Task 8 (zero-dep). Update the design spec in that same commit.

---

## Execution notes

- Do not force-push killer-saas history in a way that drops the fork network.
- Do not push to `BarthGve/ai-driven-method` until the user confirms.
- `gh` auth is required for Task 1 (fork) and later live smokes; unit tests must not call the real API.
