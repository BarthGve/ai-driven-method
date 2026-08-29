---
description: Write the user-facing product page for a story (wiki input). No wiki push.
argument-hint: <story id or name>
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Bash
---
# dm-docs — Product page for one US

Target story: $ARGUMENTS

Resolve $ARGUMENTS to the story id (`s<number>-<slug>`) against docs/stories.md. No unambiguous match → list matches and stop.

## Workspace
Locate `.worktrees/<id>`, verify branch `feature/<id>`, and write there. Missing worktree → STOP and run `/dm-research <id>` first. Never switch branches here.

## Prerequisites (fail-closed)
1. `docs/plans/<id>.md` exists and frontmatter has `validated: yes`. Otherwise STOP: "Plan not validated — run /dm-plan <id>."
2. No board readiness gate — docs is story framing; child tickets may still be in `backlog`.

## Produce
Write `docs/product/<id>.md` from `@templates/product-doc.md`, using:
- the story in docs/stories.md (purpose, acceptance criteria → visible rules / out of scope)
- docs/designs/<id>.md when the story has UI (user flow)
- docs/plans/<id>.md for scope boundaries

User-facing only. No research, no plan tasks, no review jargon.

## Explicitly out of scope
- Do **not** push to the wiki. Wiki publish is `/dm-release` only (`bash .dm/lib/dm-wiki.sh publish …`).

End with: "Product doc ready in docs/product/<id>.md. Required before the first /dm-ship for this US. Next: move a child ticket to ready, then /dm-execute <id> <ticket>."
