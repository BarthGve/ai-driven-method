---
description: Derive a story's screen from the design system — agent, native /design canvas on Claude, or external brief. Use after /dm-research for a story with UI. Not for the global system (/dm-design-system) or stories without UI.
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

**CANVAS path (`/design`, Claude Code only)** — read `templates/design-path-canvas.md` now and follow it. Artboards land as `docs/designs/<id>.dc.html` plus `docs/designs/<id>.md`; the published Artifact is not the deliverable.

**EXTERNAL BRIEF path** — read `templates/design-path-brief.md` now and follow it. The deliverable is `docs/designs/<id>-brief.md`, then the returned mockup.

### Step 5 — Gaps
Any need the design system doesn't cover → record it under "Design system gaps" in the .md. DON'T invent it.

Timebox: defined enough to unblock the Plan, not pixel-perfect.

## Mockup status (hard rule)
docs/designs/<id>.html is a REFERENCE, not code to copy. In Execute, the screen is built with the boilerplate's real components. The mockup communicates intent (layout, states); it doesn't replace the component system and never gets pasted into production.

No board readiness gate — design is story framing; child tickets may not exist yet.

End with: "Design ready (docs/designs/<id>.md + .html). Next step: /dm-plan <id>"
