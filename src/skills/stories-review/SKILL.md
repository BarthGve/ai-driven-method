---
name: stories-review
description: Reviews a user-story breakdown against the PRD perimeter — coverage gaps, graveyard leaks, technical-layer stories, untestable criteria, dependency order. Preloaded in the stories-reviewer subagent.
---
# Story breakdown review

A breakdown looks fine until you check it against the perimeter it came from. This review hunts the gap between what the PRD promised and what the stories actually deliver.

Why it runs here: a defect in `docs/stories.md` costs a markdown edit now, and contaminates research, design, plan, code, review and ship for every story derived from it later.

## Checks, in order

1. **Perimeter coverage** — every feature in the PRD's "Replicated (core loop)" table must be delivered by at least one story. Walk the table, not the stories: it is the only way to see what is *missing*. A silently dropped feature is invisible until ship.
2. **Graveyard leak** — nothing from "Explicitly NOT replicated" comes back as a story. That list exists to kill scope creep; a leak defeats the PRD.
3. **Technical layers disguised as stories** — "set up the database", "create the API layer". No end-to-end user value, nothing testable, unshippable alone. The table gets created *inside* the story that needs it.
4. **Untestable acceptance criteria** — each criterion must be able to become a test. "The form works" is not a criterion; "submitting a valid form shows a confirmation and persists the entry" is.
5. **Dependency order** — no cycle, no forward reference (a story assuming work scheduled after it). The order must be executable top to bottom.
6. **Complexity** — a 5 never stays one story: it must already be split. A 4 must state its risk in the agentic notes.
7. **Ids** — `s<number>-<slug>`, unique, short, stable. They name every pipeline file and the story branch, so a malformed or duplicated id breaks the whole cycle.
8. **Overlap** — two stories claiming the same slice, or one story bundling two unrelated values.

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

## Severity scale

- **critical** — the product would be incomplete or out of scope: an uncovered perimeter feature, a graveyard leak, an impossible dependency order.
- **major** — a real defect in one story: technical layer, untestable criteria, an unsplit 5, duplicated id, two stories overlapping.
- **minor** — wording, id style, a missing agentic note, a 4 whose risk isn't spelled out.

## What this review is NOT

Not an implementation review. How a story will be built belongs to `/dm-research` and `/dm-plan`. Judge the breakdown, not the future code — and never rewrite the stories: report, the human fixes.

## Heuristics (filled)

- **Coverage walk** — start from the PRD perimeter table (Replicated / In scope), not from the stories list. Each row needs ≥1 delivering story; missing rows are critical.
- **Graveyard leak = critical** — any story that implements Explicitly NOT replicated / Out of scope fails the review hard.
- **Unsplit 5 = major** — a complexity-5 story still standing as one id must be split before planning.
- **Technical-layer stories = major** — “create the schema”, “wire the API” without user-visible value.
- **Coverage threshold** — 100% of perimeter rows mapped; partial mapping is incomplete product, not a style issue.
