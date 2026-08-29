# driven — Design spec

Date: 2026-08-29  
Status: approved  
Repo: method toolkit, published as a **GitHub fork** of killer-saas, installed into an application project

## 1. Goal

Ship a GitHub repository that packages an agentic development method. A user installs it into an application project and gets commands, skills, agents, templates, rules, git hooks, and GitHub automation.

**Provenance:** ai-driven-method is a **public GitHub fork** of [MikeCodeur/killer-saas](https://github.com/MikeCodeur/killer-saas) (Mike Codeur). We keep the fork relationship, git history, and explicit credit. We do not present driven as an original method. Principle (inherited): no direct coding of features. Gates are mechanical (files, board column, git hooks, GitHub protection, CI).

Success for V1:

- Repository published as a GitHub fork of `MikeCodeur/killer-saas` (renamed `ai-driven-method`), with `upstream` pointing at the original
- `curl | bash` install for Claude Code, Codex, and Grok
- Framing + per-story cycle + release to production
- GitHub repo, board, wiki, `main`/`next` created by `/dm-init`
- Tickets live on the board from backlog to shipped
- High-quality code bar (security, factorization, maintainability) blocks ship
- Semver bump on `next` → `main`

## 2. Identity

| Item | Value |
| --- | --- |
| Name | ai-driven-method |
| GitHub | Fork of `MikeCodeur/killer-saas`, published as `ai-driven-method` under `BarthGve` |
| Command prefix | `/dm-*` |
| Product modes | Hybrid: clone an existing SaaS **or** greenfield |
| Stack | Proposed from the PRD and the repo; never hardcoded to Next.js |
| Language | English for commands, skills, agents, templates, `AGENTS.md`. `/dm-help` in French |
| Install targets | `claude`, `codex`, `grok`, `all` |

## 3. Pipeline

### Framing (once per product)

1. `/dm-prd` — WHAT + WHY. First question: clone vs greenfield. Write `docs/prd.md`.
2. `/dm-init` — propose GitHub repo, `main` + `next`, protection, Project board, wiki, `VERSION`, CI workflow. Nothing created without confirmation.
3. `/dm-stories` — agentic-ready slices + **one parent Issue per US** in **backlog** (no child tickets yet).
4. `/dm-stories-review` — fresh-context review vs PRD (soft gate).
5. `/dm-architect` — analyze existing code or recommend a stack from the PRD; ADRs; inject conventions into `AGENTS.md`.
6. `/dm-design-system` — capture tokens/components; never invent visuals.

### Per story (framing — no `ready` gate)

US id: `s<number>-<slug>`. Too big (complexity 5, or a plan that cannot be cut into a handful of tickets) → split into **several US**, not into a giant ticket list.

7. `/dm-research` — current code, verified APIs, premise check. Story worktree `feature/<story-id>` (docs only).
8. `/dm-design` — UI stories only; anchored to the design system.
9. `/dm-plan` — cut the US into **child tickets** (`t<number>-<slug>`), each a coherent slice of work with tasks, dependencies, a **size** (XS–XL) and a **person-day estimate**. Human sets `validated: yes`. Then create **one child Issue per ticket**, column **backlog**, linked to the parent US.
10. `/dm-docs` — product-facing page `docs/product/<story-id>.md` (after the plan is validated). Story-level, not per ticket.

### Per ticket (child must be ≥ `ready`)

Full ticket id: `<story-id>/<ticket-id>` (e.g. `s01-submit-testimonial/t01-persist-entry`). One ticket = one worktree = branch `feature/<story-id>/<ticket-id>` = one PR into `next`.

11. `/dm-execute <story> <ticket>` — TDD via `implementer`. Primary context does not write code. Fail-closed unless that **child** is `ready` or `in progress`.
12. `/dm-review <story> <ticket>` — `reviewer`; quality bar; `docs/reviews/<story-id>/<ticket-id>.md`; `Ship allowed: yes` or `no`.
13. `/dm-ship <story> <ticket>` — PR `feature/<story-id>/<ticket-id>` → **`next`**. On merge: **child** → **test**. If every sibling is `test` or `shipped`, **parent US** → **test**.

### Production

14. `/dm-release` — PR `next` → `main` only. User confirms major/minor/patch. On merge: bump, tag, every child in `test` whose US is fully on `next` → **shipped**, parent US → **shipped**, wiki (one page per US).

### Utilities

- `/dm-orchestrator <story>` — research → design → plan → docs, then **stops** and lists child tickets still in `backlog` (you move them to `ready`).
- `/dm-orchestrator <story> <ticket>` — execute → review → ship for that child, checkpoints plan already validated + ship. Same contracts as standalone commands.
- `/dm-status` — framing + each US with its children (columns, reviews, next command).
- `/dm-help` — French pipeline map. User-invoked only.

### Quick Fix

Explicit user request only. Small, local, reversible, no architectural/business impact. Primary agent edits on **`next`**, never on `main`, never in a story worktree. Announce scope, minimal diff, proportionate verification. If investigation shows feature-sized impact → stop and return to the pipeline.

## 4. Git flow

| Branch | Role | Allowed inbound |
| --- | --- | --- |
| `main` | production, protected | only `next` |
| `next` | integration | PRs from `feature/<story-id>` (docs) and `feature/<story-id>/<ticket-id>` (code) |
| `feature/<story-id>` | story framing (research, design, plan, product doc). Docs only, no app code | created from current `next` |
| `feature/<story-id>/<ticket-id>` | one child ticket, dedicated worktree | created from current `next` (after story docs are on `next`, or the first ticket PR carries the story docs) |

Worktree paths: `<repo>/.worktrees/<story-id>` (framing) and `<repo>/.worktrees/<story-id>/<ticket-id>` (implementation). Feature branches are never checked out in the repository base directory.

Default branch for the application repo is `main`. `/dm-init` creates `next` from `main` at setup. After the first release, `next` may be ahead of `main`; new story and ticket branches come from `next`.

Always squash-merge. One **ticket** = one commit on `next`. One release = one commit on `main` (includes version bump + changelog). A US may therefore land as several commits on `next` (one per child ticket).

## 5. GitHub board

GitHub Projects V2. Same five statuses for every card:

`backlog` · `ready` · `in progress` · `test` · `shipped`

Two Issue types on the same board:

| Card | Created by | Title | Body |
| --- | --- | --- | --- |
| **US (parent)** | `/dm-stories` | `[s01-…] title` | user story, acceptance criteria, link to `docs/stories.md` |
| **Ticket (child)** | `/dm-plan` after `validated: yes` | `[s01-…/t01-…] title (M, 1.5d)` | slice of work, tasks, dependencies, **size**, **estimate in person-days**, parent US |

Prefer GitHub **sub-issues** (parent/child). If unavailable, child body has `Parent: #<us-issue>` and a label `ticket`.

**Child ticket columns** (the cards you move to `ready`):

| Column | Who moves | When |
| --- | --- | --- |
| backlog | `/dm-plan` | ticket created |
| ready | **user only** | authorizes **this** ticket’s implementation |
| in progress | method | `/dm-execute` for that ticket |
| test | method | `/dm-ship` merge into `next` |
| shipped | method | `/dm-release` merge into `main` |

After `ready`, the user does not move child cards. Commands do.

**Parent US columns** (never `ready` — that column is for children only):

| Column | Who moves | When |
| --- | --- | --- |
| backlog | `/dm-stories` | US written; stays here through research/plan |
| in progress | method | first child enters `in progress` |
| test | method | **all** children are `test` or `shipped` (every ticket is on `next`) |
| shipped | method | `/dm-release` — US is on `main` |

**Ready gate (children only):** `/dm-execute`, `/dm-review` (implementation), `/dm-ship`, `/dm-orchestrator <story> <ticket>` refuse if the **child** is `backlog` or missing. `in progress` allowed (resume / fix). `test` / `shipped` refuse a new execute except fix mode while still `in progress`.

`/dm-research`, `/dm-design`, `/dm-plan`, `/dm-docs` do **not** require `ready` (tickets do not exist yet). They run on the story worktree.

A child with unmet ticket dependencies (plan `dependencies:`) cannot be executed even if `ready`; the command lists blockers and stops.

### Ticket size and person-day estimate

Every **child ticket** has two required planning fields. They are not the same thing:

| Field | Meaning | Allowed values |
| --- | --- | --- |
| **size** | Complexity / uncertainty of the slice | `XS` · `S` · `M` · `L` · `XL` |
| **estimate** | Calendar effort for one person | person-days, positive multiples of **0.5** (0.5, 1, 1.5, …). No 0 |

US **complexity 1–5** stays on the parent. Ticket **size** is T-shirt. Do not mix the two scales.

Guide (not a gate): XS ≈ 0.5d, S ≈ 1d, M ≈ 1–2d, L ≈ 2–3d, XL ≈ 3–5d. An XL at 0.5d or an XS at 5d is a **warning** at plan validation; the human can still confirm.

- Set in `/dm-plan`: the agent **proposes** both from research and ticket scope; the human can change them at validation. Missing **size** or **estimate** on any ticket → cannot `validated: yes`.
- Stored in `docs/plans/<story-id>.md` as `size: M` and `estimate: 1.5` on each ticket. Copied onto the GitHub Issue: title `(M, 1.5d)`, body `Size: M` / `Estimate: 1.5d`.
- **Parent US** shows the **sum of estimates** and a **count of sizes** (e.g. 2×M, 1×S). Both derived, never typed separately.
- `/dm-status` shows per child size + estimate, US total person-days, remaining effort (children not yet `test` or `shipped`).
- Planning figures only. V1 does not track actuals.

Changing size or estimate after validation is a plan edit (re-run `/dm-plan` or edit the plan file and the Issue); it does not by itself move the ticket.

## 6. Quality bar

Skill `quality-bar` is preloaded in `implementer` and `reviewer`. Quality is how the plan is implemented, not extra features.

| Axis | Implementer | Reviewer |
| --- | --- | --- |
| Security | Authz next to the rule, validate inputs, no secrets, no injection, no IDOR, no sensitive logs | OWASP on the diff |
| Factorization | Reuse research anchor points; one business rule, one place | Duplicate rule, copied flow, wrong layer |
| Maintainability | Small units, clear names, no dead code, no speculative abstraction | God functions, coupling, lying comments, unjustified complexity |
| Tests | TDD that bites (mutation); no decorative tests | Neutralize invariant; 0 red = untested |
| UI | Design-system components only | Token/component drift |

Severity (stricter than killer-saas):

- **critical** → `Ship allowed: no`: security hole, data leak, authz bypass, invented API, untested or duplicated business rule, behavior regression.
- **major** → `Ship allowed: no` as well when the defect is in this diff: copy-paste of an existing flow, module that cannot evolve, plan ignored, design-system break of visual coherence.
- **minor**: style, naming, small cleanup → ship allowed.

One critical **or** one major = no ship. `/dm-execute` fix mode, then a new `/dm-review`. Maximum two fix loops in the orchestrator, then stop with open findings.

Reviewer is fresh-context, read-only except temporary test mutation, restored (`git diff --exit-code`) before the report. Report ends with:

```
Max severity: <critical|major|minor|none>
Ship allowed: <yes|no>
```

Reviewer also lists what could not be verified.

## 7. Versioning

- Canonical file: `VERSION` at app repo root. `/dm-init` writes `0.1.0`.
- `/dm-architect` records how to sync the detected manifest (`package.json`, `pyproject.toml`, …).
- Bump **only** in `/dm-release`. One bump per release, even if several stories ship.
- Command lists stories in `test`, **proposes** patch / minor / major, user confirms.
  - patch: fixes, Quick Fix, no new capability
  - minor: at least one story adds a capability (default)
  - major: breaking (API, data, user journey) or user request
- On merge to `main`: `VERSION` + manifest + `CHANGELOG.md` in the release commit, git tag `vX.Y.Z`, wiki Home shows that version.

## 8. Product wiki

Source of truth: `docs/product/<id>.md` (template `templates/product-doc.md`). User-facing: purpose, flow, visible rules, out of scope. Not research/plan/review.

`/dm-docs <story>` runs after the plan is validated, before execute. `/dm-ship` refuses without `docs/product/<id>.md`. UI stories use the design as input; non-UI stories use the story + plan.

Publish **only** on `/dm-release` merge to `main`:

- Push/update wiki pages for stories moving to `shipped`
- Update `Home.md` index + version
- Stories still only on `next` stay off the wiki

Mechanism: `gh` + git remote `<app>.wiki.git`. Wiki enabled at `/dm-init`.

## 9. Provenance, fork, and credit

ai-driven-method **must** be published as a GitHub fork, not a clean repo that copies files.

- Create via `gh repo fork MikeCodeur/killer-saas --fork-name ai-driven-method` (or the GitHub Fork button). Default remote `origin` = the fork; `upstream` = `MikeCodeur/killer-saas`.
- Keep the full git history of killer-saas. Our work is commits on top of that history.
- README and DOC.md open with credit: method derived from killer-saas by Mike Codeur, link to https://github.com/MikeCodeur/killer-saas, list of material changes (hybrid PRD, Grok, board, wiki, `main`/`next`, quality bar, semver).
- `NOTICE` file: original author, fork relationship, that `<< IP Mike >>` zones in upstream were empty placeholders and our filled heuristics are fork additions.
- Upstream has **no LICENSE file**. We do not invent a license for Mike's files. We do not strip author or history. If we add a license, it applies only to files we add in the fork, and README says so.
- `install.sh` clone URL points at **this fork**, not at `MikeCodeur/killer-saas`.
- Do not remove the fork network on GitHub (no “detach fork” / delete parent).

## 10. Method repository layout

```
src/AGENTS.md
src/commands/dm-*.md
src/agents/{implementer,reviewer,stories-reviewer,worktree-manager}.md
src/skills/{agentic-stories,codebase-analysis,tdd-skill,quality-bar,stories-review}/SKILL.md
src/templates/
src/hooks/{dm-gate.sh,pre-commit,pre-push}
install.sh
bin/dm-build.mjs
.github/workflows/dm-gate.yml   # template copied into the app at /dm-init
docs/superpowers/specs/         # this spec (method development only)
```

Canonical source is Claude-shaped. `bin/dm-build.mjs` emits:

| Target | Output |
| --- | --- |
| claude | `.claude/commands`, `skills`, `agents` + `CLAUDE.md` → `@AGENTS.md` |
| codex | `.codex/skills` (commands as skills + openai.yaml) |
| grok | `.grok/commands`, `.grok/skills`, `.grok/agents` |
| shared | `AGENTS.md`, `templates/`, `.dm-manifest`, `.dm-version` |

Installer behaviour (parity with killer-saas, rebranded):

- Project (default) or `--global`, `init`, `update`, `--hooks`, `--force`, `--target`
- Manifest-tracked clean replace; never delete user-owned commands/skills
- Never overwrite `AGENTS.md` on update; skip locally modified templates unless `--force`
- `--hooks` sets `core.hooksPath=.dm-hooks`

`gh` is required for GitHub commands (`init`, board moves, ship, release, wiki). If missing or unauthenticated, those commands stop with the exact next step. Markdown-only commands (prd, research, plan, …) still work locally.

## 11. Commands — contracts

Every command that takes a story resolves `$ARGUMENTS` against `docs/stories.md`. A second argument is a ticket id resolved against `docs/plans/<story-id>.md`. Ambiguous → list matches and stop. Story framing uses `.worktrees/<story-id>`; ticket work uses `.worktrees/<story-id>/<ticket-id>`. Missing story worktree → stop and point to `/dm-research`. Missing ticket worktree → `/dm-execute` bootstraps it via `worktree-manager` only if the child is `ready`.

### `/dm-prd`

Ask one question at a time. First: clone vs greenfield.

- Clone: target SaaS, kill mode (internal vs competitor), why, 20% perimeter, complexity 1–5, graveyard, angle, then classic need/users/constraints/success.
- Greenfield: need, users, why now, in/out of scope (graveyard still used to kill creep), constraints, success. No fake “target SaaS”.

Fill only validated answers. Commit `docs/prd.md` on the current default branch (`main` before init completes, then as appropriate).

### `/dm-init`

Prereq: `docs/prd.md`. Confirm with the user: create remote, name, visibility, org/user, enable wiki, enable project.

Actions:

1. `git init` if needed; ensure `main` exists
2. `gh repo create` if confirmed
3. Create `next` from `main`
4. Protect `main`: no direct push; required PR; **only `next` as merge source**
5. Protect `next`: no direct push; required PR from `feature/*`; required CI
6. Create Project V2 with the five statuses; store project number, owner, and status field id in `.dm/config.json` so later commands do not guess
7. Enable wiki
8. Write `VERSION` (`0.1.0` if absent), `CHANGELOG.md` stub
9. Copy CI workflow into the app repo
10. Commit and push `main` + `next`

Idempotent: re-run detects existing repo/board/branches and only fills gaps.

### `/dm-stories`

Prereq: PRD + init (board config present). Apply `agentic-stories`. Each story: id, as-a/want/so-that, complexity, verifiable criteria, dependencies, agentic notes. Clone mode may point notes at the target’s equivalent screen. Create **one parent Issue per US**, status `backlog`. Do not create child tickets here. Commit `docs/stories.md`.

### `/dm-stories-review`

Delegate to `stories-reviewer`. Write `docs/reviews/stories.md`. Soft gate: status and research warn, they do not hard-stop.

### `/dm-architect`

Ask/detect boilerplate vs empty repo. If code exists: `codebase-analysis`, conform, do not rewrite. If empty: **recommend a stack from the PRD** (product type, constraints, team, clone-target tech if any) with 2–3 options and a recommendation; record the choice as ADR; scaffold only after user confirmation. Fill `docs/architecture.md`, `AGENTS.md` technical conventions, ADRs.

### `/dm-design-system`

Fail-closed: no visual source and no existing system → stop and ask. Record, do not invent.

### `/dm-research`

Worktree-manager first (story worktree, branch `feature/<story-id>`). Warn if stories-review is missing or `Stories ready: no`. Verify premises in code. Re-score complexity; propose **US split** on 5 (not a pile of tickets that hide an epic). No app code, no plan. No `ready` gate.

### `/dm-design`

Fail-closed without `docs/design-system.md`. Agent vs Claude Design vs Gemini. Gaps recorded, never invented. HTML mockup is a reference, not production code. Story-level.

### `/dm-plan`

Fail-closed without research unless user confirms. Decompose the US into **child tickets** (`t<number>-<slug>`), each implementable in one execute/review/ship cycle, with dependencies, tasks, **size** (XS–XL) and **person-day estimate** (multiples of 0.5). A ticket is a work slice (API, screen, migration), not a technical-layer US and not every checkbox. Run interdicts at ticket level. Frontmatter `validated: no` until AskUserQuestion Validate. The validation summary **must** list each ticket with size + estimate and the US total days; missing either field → cannot validate.

On Validate: write `docs/plans/<story-id>.md`; **create one child Issue per ticket** in `backlog`, linked to the parent, title/body carrying size and estimate; do not move children to `ready`.

### `/dm-docs`

Prereq: plan `validated: yes`. Write `docs/product/<story-id>.md` from the story (and design if UI). User-facing, one page per US. Required before the **first** child `/dm-ship`.

### `/dm-execute`

Arguments: story + ticket. No Write/Edit in the command’s own tool list. Delegate `implementer` in `.worktrees/<story-id>/<ticket-id>` on `feature/<story-id>/<ticket-id>`. Fail-closed: validated plan, **that child** ≥ `ready`, ticket dependencies already `test` or `shipped`. Sets child to `in progress`. Fix mode if previous review `Ship allowed: no`. One commit per ticket.

### `/dm-review`

Arguments: story + ticket. Delegate `reviewer`. Diff is `git diff <next>...feature/<story-id>/<ticket-id>`. Quality bar. Write `docs/reviews/<story-id>/<ticket-id>.md`. Gate on critical/major.

### `/dm-ship`

Arguments: story + ticket. `grep '^Ship allowed: yes'` on that ticket’s review. Require `docs/product/<story-id>.md`. Tests must pass. PR into **`next`**. Manual default: open PR, human squash-merges. After proven `MERGED`: remove ticket worktree, delete ticket branch, child → `test`. If all siblings of the US are `test` or `shipped`, parent US → `test`. Auto strategy (AGENTS.md): merge after gate.

### `/dm-release`

List **parent US** in `test` (all children already on `next`). Propose semver bump. On confirm: update `VERSION`, manifest, changelog on `next`, open PR to `main`. After merge: tag `vX.Y.Z`, those parents and their children → `shipped`, wiki pages for those US.

### `/dm-status`

Framing files, stories-review line, `VERSION`. For each US: parent column, research/design/plan/docs, **total person-days**, size mix, and **remaining** (children not yet `test`/`shipped`). Then each child: column, size, estimate, review, PR, blockers. Next command is the most useful one (often “move t02 to ready” or `/dm-execute s01 t01`).

## 12. Agents

| Agent | Model | Tools | Skills | Role |
| --- | --- | --- | --- | --- |
| implementer | high-capability pin (Claude: opus; Grok/Codex: note equivalent) | Read, Write, Edit, Bash, Grep, Glob | tdd-skill, quality-bar | TDD implement **one ticket** only |
| reviewer | inherit | Read, Grep, Glob, Bash, Edit (mutation only) | quality-bar | Judge, do not fix |
| stories-reviewer | inherit | Read, Grep, Glob | stories-review | Judge breakdown |
| worktree-manager | inherit | Read, Bash, Glob | — | Create/verify worktree, copy `.env*`, install deps |

Implementer never switches branches or works in the repo base. Worktree-manager never implements.

On Codex/Grok, tool-permission isolation is coarser than Claude; git hooks + CI hold the gates. Commands still **must not** write application code in the primary context: they delegate.

## 13. Skills (heuristics filled)

V1 writes the heuristics killer-saas left as `<< IP Mike >>`:

- `agentic-stories` — granularity, good/bad examples, criteria format
- `codebase-analysis` — archaeology sequence, how to turn conventions into AGENTS.md rules; stack recommendation when empty
- `tdd-skill` — bite mutation, no decorative tests, file budget, visual vs behavior
- `quality-bar` — security checklist, factorization, maintainability, anti-hallucination (invented APIs, plan drift), severity thresholds
- `stories-review` — coverage, graveyard leaks, technical-layer stories, dependency order

## 14. Templates

`prd.md` (hybrid sections), `stories.md`, `architecture.md`, `design-system.md`, `research.md`, `plan.md` (tickets + size XS–XL + estimate in person-days + tasks + dependencies), `design-brief.md`, `design-screen.md`, `review-checklist.md` (includes quality-bar items), `stories-review-checklist.md`, `adr.md`, `product-doc.md`.

## 15. Data & lifecycle

All pipeline data is markdown under `docs/` plus git plus GitHub Issue/Project. No extra database.

| Data | Location |
| --- | --- |
| PRD, stories, architecture, design system | `docs/*.md` on `main`/`next` after framing |
| Research, design, plan, product doc | story branch `feature/<story-id>` then `next` |
| Ticket review | `docs/reviews/<story-id>/<ticket-id>.md` on the ticket branch then `next` |
| Board / project ids | `.dm/config.json` (**JSON**, zero-dep; committed) |
| Decisions | `docs/decisions/NNN-slug.md` |
| Version | `VERSION`, `CHANGELOG.md` |
| State | derived (files + `Ship allowed:` + Issue status + git) |

Framing commits on `main` until `/dm-init` has created `next`; after that, framing that is product-wide may PR into `next` then release, or commit on `next` if that is the integration line. V1 rule: after init, **all commits go to `next` or to `feature/*`**. Direct commits on `main` are forbidden except the squash merge from `next`.

## 16. Enforcement

### Git hooks (`--hooks`)

- pre-commit: **code** on `feature/<story-id>/<ticket-id>` requires validated plan **and** `dm-gate ready-ok` (child status in `{ready, in progress}` via `dm-board.sh status-get`). If `.dm/config.json` is missing, ready-ok **warns and allows** (board not initialized). After init, missing ready **blocks**. Docs-only always allowed; story framing branch docs-only always allowed.
- pre-push: reject pushes to `main` that are not from the `next` integration flow
- pre-push: reject integrating a **ticket** branch to `next` without `Ship allowed: yes` on that ticket’s review

### GitHub (from `/dm-init`)

- `main` protected; only `next` may merge
- `next` protected; feature PRs + required CI

### CI (app repo)

PR → `next` from a ticket branch: tests + that ticket’s review `Ship allowed: yes` + product doc for the US + child Issue not `backlog`.  
PR → `next` from a story framing branch: docs only (no app code).  
PR → `main`: head is `next`; `VERSION` bumped vs target; changelog entry present.

## 17. Fail-closed matrix

| Action | Required |
| --- | --- |
| `/dm-init` | `docs/prd.md`, `gh` auth, user confirmation |
| `/dm-stories` parent Issues | init config (project id) |
| `/dm-research` / `/dm-design` / `/dm-plan` / `/dm-docs` | story worktree; no child `ready` |
| `/dm-plan` child Issues | plan `validated: yes`, every ticket has `size` (XS–XL) and `estimate` (0.5d steps) |
| `/dm-design` | `docs/design-system.md` |
| `/dm-execute` | plan `validated: yes`, **child** ≥ `ready`, ticket deps shipped to `next` |
| `/dm-ship` | that ticket `Ship allowed: yes`, `docs/product/<story-id>.md` |
| `/dm-release` | parent US in `test` on `next`, bump choice |

## 18. Out of scope for V1

- Cursor / Gemini install targets (Grok reads Claude dirs as compat, but we do not emit a Gemini adapter)
- Multi-story parallel orchestrator / native `/goal` replacement
- Auto-moving cards by the user being overridden except the documented command transitions
- Publishing pipeline artifacts (research, plan) to the wiki
- Hardcoded Next.js / ship-saas.now boilerplate
- Detaching the GitHub fork from MikeCodeur/killer-saas
- Relicensing Mike Codeur's original files (upstream has no LICENSE)
- Tracking actual person-days vs estimates (no timesheets, no burn-down beyond remaining estimate)

## 19. Testing the method

- `bin/dm-build.mjs` smoke: emit claude, codex, grok trees and assert expected paths
- `install.sh` in a temp dir: project install each target, update, `--hooks`
- `dm-gate.sh` unit-style cases: plan-validated, ship-allowed, ready-gate fixtures
- No live GitHub mutations in CI of the method repo unless secrets exist; document a manual `/dm-init` smoke on a throwaway repo

## 20. Open decisions locked by this spec

- Production branch name: `main` (not `master`)
- Shipped + wiki + version bump: merge `next` → `main`
- Board `test`: after merge into `next`
- Major quality findings block ship
- `/dm-docs` required before the first child ticket ships
- Feature branches created from `next`
- Published as a GitHub fork of `MikeCodeur/killer-saas`, repo name `ai-driven-method`, not a from-scratch repo
- Command prefix `/dm-*`
- US = parent Issue; `/dm-plan` creates child tickets; `ready` is child-only; US `test` when all children are on `next`
- Every child ticket has a required size (`XS`–`XL`) and person-day estimate (multiples of 0.5); US total days is the sum; no actuals tracking in V1
