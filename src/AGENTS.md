# driven — Repo rules

## Absolute rule
No direct coding. Every feature goes through the driven pipeline, in order:

PRD → Init → Stories → Stories Review → Architecture (+ Design System) → then, per story: Research → Design → Plan → Docs → then, per ticket: Execute → Review → Ship. Production: Release (`next` → `main`).

No code is written before the story has a validated plan (`/dm-plan`) and the **child ticket** is `ready`. No feature ships before a passed review (`/dm-review`). `ready` is child-only — a parent US never uses it.

### Quick Fix mode — exception to the pipeline

Only when the user explicitly asks for a Quick Fix: a small, local,
well-understood, easily reversible adjustment (color, spacing, radius, font,
button style, short copy or translation, small layout/responsive tweak, an
existing presentation affordance, or a similarly narrow change with no
architectural or business impact). The primary agent edits directly — no pipeline, TDD
optional, no implementation subagent (read-only investigation or optional
review only).

Never a Quick Fix: new feature, shared-component redesign, data model or
migration, API or contract, authorization, security, business rules,
persistence, cross-cutting refactor, dependency change, uncertain impact. If
the work turns out to be one of these: stop, recommend the pipeline, write no
more code.

Announce the mode and exact scope before editing; minimal diff; keep existing
abstractions; verify proportionately (focused lint, typecheck, existing test or
browser check).

Quick Fix work happens only in the repository's base directory on branch
`next` — no feature branch, no worktree, never `main`. Not on `next` → stop and
ask; never switch branches yourself. Another agent owns the base directory →
coordinate or stop.

## Pipeline (commands)
`/dm-*` commands, one per phase above. Notable: `/dm-prd` = clone an existing SaaS **or** greenfield (Not kill-only); `/dm-init` = remote, `main`/`next`, board, wiki, `VERSION`; `/dm-architect` fills `<< IP Mike >>` below; `/dm-docs` = product page (wiki publish is `/dm-release`, `next` → `main`); `/dm-orchestrator` has two modes (`<story>` = framing, `<story> <ticket>` = delivery, human checkpoints); `/dm-status` derives state incl. **remaining person-days**; `/dm-help` prints the map.

`ready` exists **only on child tickets**. Parent US: backlog → in progress → test → shipped (never `ready`).

## Git branches

| Branch | Role | Rule |
| --- | --- | --- |
| `main` | production | only updated from `next` (GitHub branch protection is the real guarantee) |
| `next` | integration | PRs from `feature/*`; Quick Fix lands here |
| `feature/<story-id>` | story framing (research, design, plan, product doc) | docs only, created from `next` |
| `feature/<story-id>/<ticket-id>` | one child ticket | implementation worktree, created from `next` |

## Where work happens

There are exactly three modes. A complexity score never chooses the directory:

| Mode | Working directory | Branch |
| --- | --- | --- |
| Explicit Quick Fix | Repository base directory | `next`; if another branch is checked out, stop and ask before continuing |
| Story framing (research / design / plan / docs) | `.worktrees/<story-id>/` | Exact `feature/<story-id>` (docs only) |
| Ticket implementation | `.worktrees/<story-id>/<ticket-id>/` | Exact `feature/<story-id>/<ticket-id>` |

Anything not announced as an eligible Quick Fix is a feature. Never create or
check out a feature branch in the repository base directory.

The `worktree-manager` subagent creates or verifies the worktree from `next`
before Research (story) or Execute (ticket). Every later phase resolves and
states the absolute worktree path and verifies the exact branch. Missing
worktree, wrong branch, detached HEAD or a second branch name is a hard stop.
Never improvise with `git switch`, `git checkout`, `git stash` or an
`-isolated` suffix.

Ports: a server, e2e run or browser check launched by an agent never uses the
developer's dev port (3000, 5173, 8080…). Get yours with `bash .dm/lib/dm-port.sh`
(stable per worktree, 20000-29999) and pass it to the tool (`PORT=$(bash .dm/lib/dm-port.sh) npm run dev`,
`--port`, or the test config's baseURL). Stop what you started before you finish.

Test services: tests in a ticket worktree never share a stateful service with
another worktree or with the developer's environment — database, schema, Redis
db index, queue or bucket prefix. Two `full` runs on one test database lock and
wipe each other: flaky reds, then reruns. The `isolation` row of Checks gives
the recipe; `worktree-manager` applies it when it creates a ticket worktree,
and `/dm-ship` runs its teardown before removing the worktree.

One agent, one working directory. While an agent owns a directory, no second
agent and no main context may edit, checkout or stash in it.

## Story ids, tickets and branches
- Every story has an id: `s<number>-<short-slug>` (e.g. `s01-submit-testimonial`). It is assigned in docs/stories.md and reused verbatim: `docs/research/<id>.md`, `docs/plans/<id>.md`, `docs/product/<id>.md`, branch `feature/<id>`.
- `/dm-plan` decomposes the US into child tickets `t<number>-<slug>`. Full work id: `<story-id>/<ticket-id>` (e.g. `s01-submit-testimonial/t01-persist-entry`). Ticket branch: `feature/<story-id>/<ticket-id>`. Ticket review: `docs/reviews/<story-id>/<ticket-id>.md`.
- Story framing and ticket branches are created from `next`. Never commit feature work to `main`.
- The ticket diff = `git diff next...feature/<story-id>/<ticket-id>`. That is what the review judges.
- A command that receives a fuzzy story name resolves it against docs/stories.md; a second argument is a ticket id resolved against docs/plans/<story-id>.md. Ambiguous → list matches and stop.

## Gate (mechanical)
- The ticket review `docs/reviews/<story-id>/<ticket-id>.md` ends with the verdict lines defined by the quality-bar skill. A single critical or major = `Ship allowed: no`.
- `/dm-ship` refuses to run unless that file exists and contains the line `Ship allowed: yes`. No file, no line, or `no` → ship blocked. No exceptions.
- After a blocked review, `/dm-execute` runs in fix mode: the review findings are fed to the implementer and fixed before anything else.
- A plan executes only if its frontmatter says `validated: yes` — set by the human validation checkpoint (/dm-plan or the orchestrator), never by the file merely existing. /dm-execute is fail-closed on it.
- `dm-gate.sh` treats `next` as the integration branch and `main` as production. Client-side pre-push refuses non-`next` updates to `main`; GitHub branch protection is the real guarantee for `main`.

## Ship strategy
Merge mode: manual   (manual | auto — default: manual)
Target of `/dm-ship`: **`next`** (per ticket). Production (`main`) is updated only by releasing `next` → `main`.
- manual: /dm-ship opens the PR into `next` and stops. Merging is a human decision (review on GitHub, protected branch, CI). After the merge, rerun /dm-ship to confirm cleanup. Parent US moves to `test` only when every child is `test` or `shipped`.
- auto: /dm-ship merges into `next` immediately after the gate. Only for solo flows where running /dm-ship IS the decision.

## Design
Global system: `docs/design-system.md`; per story: `docs/designs/<id>.md` (+ reference `.html` mockup, never pasted as code). Never invent a component or token outside the system — report a "design system gap". Stories without UI skip `/dm-design`.

## Data & docs lifecycle
All pipeline data lives in markdown files under docs/, versioned by git. No database, no state file: the pipeline state is derived from the files (a story is planned if docs/plans/<id>.md exists, a ticket is shippable if its review says `Ship allowed: yes` and the branch is merged into `next`) — a derived state can't go stale.

- Framing docs — docs/prd.md, docs/stories.md, docs/reviews/stories.md, docs/architecture.md, docs/design-system.md: land on `next` (then `main` via release). 
- Story docs — docs/research/<id>.md, docs/designs/<id>* (brief, md, html), docs/plans/<id>.md, docs/product/<id>.md: committed on `feature/<id>`, then into `next`.
- Ticket reviews — docs/reviews/<story-id>/<ticket-id>.md: committed on the ticket branch; /dm-ship commits the review. Every ticket PR carries its review.
- Task progress — the checkboxes in docs/plans/<id>.md: the implementer ticks each **ticket** task as it lands. The plan file is the live progress tracker, never a commit trigger.
- Estimates — each child ticket has `size` (XS–XL) and `estimate` (person-days, 0.5 steps). US total = sum. **Remaining person-days** = sum of estimates of children not yet `test` or `shipped` (`/dm-status`). No actuals in V1.
- Commits — **one commit per ticket** (squash into `next`). A second commit only for something you would want to revert on its own (typically a migration). One release = one squash commit on `main`.
- Decisions — docs/decisions/NNN-<slug>.md (MADR format, templates/adr.md): one file per structural decision, with the considered options and why they were rejected. Immutable: a change means a new ADR superseding the old one.

## Technical conventions
<< IP Mike: boilerplate structure, stack, patterns, naming, commit rules. >>

## Checks
Filled by `/dm-architect` with the project's real commands, nothing aspirational.

| Tier | When | Command |
| --- | --- | --- |
| focused | during a task, mutations | << run given test files, e.g. `npx vitest run <files>` >> |
| fast | before the ticket commit | << lint + typecheck >> |
| full | before the ticket commit, review, ship | << whole test suite >> |
| ci | CI only, never run by an agent | << coverage, full mutation, build, e2e suite >> |
| isolation | ticket worktree creation; teardown at ship cleanup | << per-worktree test services, e.g. `DATABASE_URL=…/app_test_$(bash .dm/lib/dm-port.sh)` in `.env.test.local`, then the create/migrate command; teardown: the drop command. `none` when tests use no stateful service >> |

- `focused` runs only the test files of the unit at hand, never the whole suite.
- `isolation` names derive from `dm-port.sh` run inside the worktree: stable per worktree, distinct across worktrees. The overrides go to a file the test runner loads and git ignores (`.env.test.local`, or the framework's equivalent), never to a tracked file.
- `fast` and `full` always go through the witness, which skips a check this exact content already passed: `bash .dm/lib/dm-witness.sh full -- <full command>`. No `.dm/lib/dm-witness.sh` in the worktree (branch older than the script) → run the command directly and say so.
- Missing section or placeholder → discover the commands (`package.json`, `pyproject.toml`, `Makefile`, CI config). Never invent a runner.

## Definition of Done (per ticket / release)
- Ticket: single PR into `next`, structured description, readable diff, passing tests, review passed (no open critical or major), merged to `next`
- Release: `next` → `main`, version bumped, deployed to production
