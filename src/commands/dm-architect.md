---
description: Set the technical HOW — stack, patterns, conventions, checks, ADRs. Use once per product, after /dm-stories-review. Not for one story's context (/dm-research) or visuals (/dm-design-system).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---
You are setting the product's technical architecture.

Read: docs/prd.md, docs/stories.md
Output structure: @templates/architecture.md

Apply the codebase-analysis skill to analyze the starting code (boilerplate): structure, conventions, existing patterns. This is code the user didn't write — map it before deciding anything.

Proceed as follows:
1. The boilerplate question (AskUserQuestion): does the project start from a boilerplate / non-empty codebase?
   - **Boilerplate or app code present:** analyze it (next steps). Conform; do not rewrite the stack.
   - **Empty / no usable boilerplate:** do **not** hardcode ship-saas.now vs Next.js. From the PRD (product type, clone-target tech if any, data/auth/realtime needs, team and constraint notes), propose **2–3 concrete stacks** with a short recommendation, plus the option **“blank repo, record ADRs only”** (method loses its main speed lever — say so plainly). AskUserQuestion for the choice. Record the stack as an ADR. **Scaffold only after the user confirms**; then analyze the scaffolded tree like any boilerplate.
2. Analyze the existing repo and document its actual structure and conventions.
3. Fill the architecture template from this analysis + the PRD needs.
4. Check/complete the AGENTS.md file at the root with the concrete technical conventions ("Technical conventions" section) and the "Checks" table: the real `focused`, `fast` and `full` commands, what stays in CI, and the `isolation` recipe: for each stateful service the tests touch (database, Redis, queue, bucket), the variable to override with a per-worktree name, where the runner reads it, the command that creates/migrates it and the one that drops it — `none` when the tests touch none. Run the recipe once in a scratch directory to prove it. Only commands that exist and run.
5. Record each imposed structural decision (stack, patterns, integrations) as an ADR in `docs/decisions/NNN-<slug>.md`, following @templates/adr.md — with the considered options and why they were rejected.
6. Write the architecture to `docs/architecture.md` and commit it together with AGENTS.md and the ADRs on the default branch (docs: architecture).

End with: "Architecture ready + AGENTS.md updated. Next step: /dm-design-system (once), then /dm-research <story>"
