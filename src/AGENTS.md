# driven — Repo rules

Each `/dm-*` command and subagent carries its own procedure; this file holds only
what applies in every session. Phase map: `/dm-help`. Project state: `/dm-status`.

## Absolute rule
No direct coding. Every feature goes through the pipeline: PRD → Init → Stories →
Stories Review → Architecture (+ Design System) → per story: Research → Design →
Plan → Docs → per ticket: Execute → Review → Ship. Production: Release (`next` → `main`).

No code before the story's plan is `validated: yes` and the **child ticket** is
`ready` (`ready` is child-only, never on a parent US). No ship before a review
whose last round says `Ship allowed: yes` — a single critical or major blocks it.

### Quick Fix mode — the only exception
Only when the user explicitly asks for a Quick Fix: a small, local, reversible
presentation change (color, spacing, font, button style, short copy or
translation, small layout tweak) with no architectural or business impact. The
primary agent edits directly, TDD optional, no implementation subagent.

Never a Quick Fix: new feature, shared-component redesign, data model or
migration, API or contract, authorization, security, business rules,
persistence, cross-cutting refactor, dependency change, uncertain impact. If the
work turns out to be one: stop, recommend the pipeline, write no more code.

Announce the mode and exact scope first; minimal diff; verify proportionately
(focused lint, typecheck, existing test or browser check). Only in the
repository base directory on branch `next` — not on `next` → stop and ask, never
switch branches yourself.

## Branches and directories

| Work | Directory | Branch (created from `next`) |
| --- | --- | --- |
| Production | — | `main`, only updated from `next` by `/dm-release` |
| Integration, Quick Fix | repository base | `next` |
| Story framing (docs only) | `.worktrees/<story-id>/` | exactly `feature/<story-id>` |
| Ticket implementation | `.worktrees/<story-id>/<ticket-id>/` | exactly `feature/<story-id>/<ticket-id>` |

Never create or check out a feature branch in the repository base. Wrong path,
wrong branch or detached HEAD is a hard stop — never repair it with `git switch`,
`git checkout` or `git stash`. One agent, one working directory: while an agent
owns a directory, nobody else edits, checks out or stashes in it.

Ids: story `s<number>-<slug>` (docs/stories.md), ticket `t<number>-<slug>`
(docs/plans/<story-id>.md), work id `<story-id>/<ticket-id>`. A fuzzy name is
resolved against those files; ambiguous → list matches and stop.

## Ship strategy
Merge mode: manual   (manual | auto — default: manual)

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
- `fast` and `full` go through the witness, which skips a check this exact content already passed: `bash .dm/lib/dm-witness.sh full -- <full command>`. No `.dm/lib/dm-witness.sh` in the worktree → run the command directly and say so.
- Missing section or placeholder → discover the commands (`package.json`, `pyproject.toml`, `Makefile`, CI config). Never invent a runner.
