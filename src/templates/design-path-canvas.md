<!-- driven — read by /dm-design only when this path is chosen. Instructions, not an output structure. -->
# /dm-design — canvas path

**CANVAS path (`/design`, Claude Code only)** — you draft the artboards in this session:

1. Invoke `/design` with the design system **copied into the request**: tokens (colors, typography, spacing, radius), the available components and the do/don't from `docs/design-system.md`, plus the story's screens, fields, actions and four states. The canvas is bound by the same contract as every other path — inventing a token, a color or a component outside the design system is forbidden here too.
2. Draft the artboards as `docs/designs/<id>.dc.html`, inside the story worktree. They are files: they get committed like any other deliverable.
3. Write `docs/designs/<id>.md` (structure: @templates/design-screen.md) describing the screens and pointing to the artboards.

**The published Artifact is not the deliverable.** It is where the user refines the design visually, but `/dm-plan`, the `pre-commit` and `pre-push` hooks all read files. A story whose design lives only in an Artifact does not pass the gate.

**Re-running.** `/design` creates or re-seeds a canvas; an existing one is edited in its published Artifact. So if `docs/designs/<id>.dc.html` already exists, do **not** re-invoke blindly: ask (AskUserQuestion) whether to re-seed the canvas from scratch or to keep the current artboards and let the user edit the published Artifact.
