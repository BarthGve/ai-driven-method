---
description: Derive a story's screen from the design system. Agent path (generates), native /design canvas on Claude, or external brief. Never freestyles outside the system.
argument-hint: <story id or name> [--agent | --canvas | --brief]
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - AskUserQuestion
  - Bash
---
# dm-design — Story design, anchored to the design system

Target story: $ARGUMENTS

Resolve the story id, then locate its dedicated `.worktrees/<id>` worktree.
Before any read or write, verify that it is on exactly `feature/<id>` and use
that absolute path for the whole command. Missing worktree, wrong branch,
detached HEAD or the repository base directory itself → STOP and run
`/dm-research <id>` to bootstrap the feature workspace. Never switch branches.

## Execution contract (non-negotiable)
You are FORBIDDEN from:
- Producing a design without an existing design system (see Step 1).
- Inventing a component, token, color or spacing outside the design system.
- Designing a screen the story doesn't ask for.

## Workflow

### Step 1 — Prerequisites (fail-closed)
Check that docs/design-system.md exists AND is non-empty.
- Missing or empty → STOP. Reply: "No design system found in docs/design-system.md. Set it up first via /dm-design-system, then rerun /dm-design." Produce NO design.
- Present → load it. Its tokens and components are your only visual source, whichever path is chosen.

### Step 2 — Tool choice
If the user didn't specify the path in $ARGUMENTS, ask (AskUserQuestion): "Who produces this story's design?"
- Agent (I generate it now)
- Claude Design canvas (`/design`) — I draft the artboards in this session; you refine them visually in the published Artifact. **Claude Code only.**
- External brief (Gemini, or any other tool) — I write the brief, you produce the screens and bring back the result.

On **Codex** and **Grok** the `/design` canvas does not exist: offer Agent and External brief only, and say why rather than proposing a path the tool cannot run.

### Step 3 — Read the story
Read docs/stories.md, resolve the target story id (`s<number>-<slug>`) and isolate its acceptance criteria. Read docs/research/<id>.md if it exists — its anchor points tell you which pages and layouts the screen plugs into. If the PRD names a target SaaS, its equivalent screen is a layout/UX reference — structure and states only, never visual identity: tokens and components come exclusively from the design system. The design covers this screen only.

### Step 4 — Produce, per the chosen path

**AGENT path** — you generate:
- docs/designs/<id>.md (structure: @templates/design-screen.md)
- docs/designs/<id>.html — a static HTML mockup of the screen, using EXCLUSIVELY the design system's tokens (colors, typography, spacing). Low fidelity. Goal: communicate layout + states, not be production code.

**CANVAS path (`/design`, Claude Code only)** — you draft the artboards in this session:

1. Invoke `/design` with the design system **copied into the request**: tokens (colors, typography, spacing, radius), the available components and the do/don't from `docs/design-system.md`, plus the story's screens, fields, actions and four states. The canvas is bound by the same contract as every other path — inventing a token, a color or a component outside the design system is forbidden here too.
2. Draft the artboards as `docs/designs/<id>.dc.html`, inside the story worktree. They are files: they get committed like any other deliverable.
3. Write `docs/designs/<id>.md` (structure: @templates/design-screen.md) describing the screens and pointing to the artboards.

**The published Artifact is not the deliverable.** It is where the user refines the design visually, but `/dm-plan`, the `pre-commit` hook and the CI gate all read files. A story whose design lives only in an Artifact does not pass the gate.

**Re-running.** `/design` creates or re-seeds a canvas; an existing one is edited in its published Artifact. So if `docs/designs/<id>.dc.html` already exists, do **not** re-invoke blindly: ask (AskUserQuestion) whether to re-seed the canvas from scratch or to keep the current artboards and let the user edit the published Artifact.

**EXTERNAL BRIEF path (Gemini or any other tool)** — you write the brief, the user produces the screens:
1. Write docs/designs/<id>-brief.md (structure: @templates/design-brief.md): every screen with layout, exact fields and actions, the four states, and the design system constraints COPIED IN (tokens, components, do/don't) so the brief is self-contained and pasteable into the external tool. Out-of-scope stated. This file is the deliverable of this step — not a chat message.
2. The user takes the brief to their design tool and brings back the result (exported HTML, screenshot, or description). You then: record/normalize the mockup into docs/designs/<id>.html, and write docs/designs/<id>.md (structure: @templates/design-screen.md) describing the screen and pointing to the HTML.
If the user brought nothing back → end with: "Brief ready in docs/designs/<id>-brief.md — take it to your design tool, then rerun /dm-design <id> with the result." Don't generate in their place, unless they explicitly switch to the Agent path.

### Step 5 — Gaps
Any need the design system doesn't cover → record it under "Design system gaps" in the .md. DON'T invent it.

Timebox: defined enough to unblock the Plan, not pixel-perfect.

## Mockup status (hard rule)
docs/designs/<id>.html is a REFERENCE, not code to copy. In Execute, the screen is built with the boilerplate's real components. The mockup communicates intent (layout, states); it doesn't replace the component system and never gets pasted into production.

No board readiness gate — design is story framing; child tickets may not exist yet.

End with: "Design ready (docs/designs/<id>.md + .html). Next step: /dm-plan <id>"
