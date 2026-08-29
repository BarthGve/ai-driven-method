---
name: codebase-analysis
description: Analyzes existing code you didn't write — structure, conventions, patterns. Use during the Architecture and Research phases of the driven pipeline, and for boilerplate onboarding.
---
# Codebase analysis

Goal: understand inherited code before touching it, and extract the conventions to follow.

Sequence — breadth first, then one deep cut:
1. Map the structure: folders, entry points, layers, build and config files.
2. Follow ONE representative feature end to end (route → handler → data access → UI): that walk exposes the real conventions faster than any doc.
3. Spot the recurring patterns: naming, organization, error handling, data access, tests.
4. Identify the implicit conventions: what the code always does the same way is law, even if written nowhere.
5. Locate the anchor points: where a new feature plugs in.
6. Report in an actionable form — conventions as rules ("server actions live in src/actions, one file per domain"), not observations ("there are some actions"). This is what feeds AGENTS.md and the architecture doc.

Rules:
- Verify, don't assume: name a file, a function or a signature only after opening it.
- Don't propose rewrites. The boilerplate is imposed: conform to it.

## Heuristics (filled)

- **Breadth-first map, then one vertical slice** — folders/entry points/config first; then one feature route → handler → data → UI. That cut beats reading every file.
- **Conventions as rules, not observations** — write “server actions live in `src/actions`, one file per domain”, not “there are some actions”. Rules feed `AGENTS.md` and `docs/architecture.md`.
- **Empty repo** — recommend a stack from PRD constraints (product type, clone-target tech if any, data/auth/realtime, team). Language or package manager already present in the repo wins over greenfield preference. Propose 2–3 options + blank-ADR-only; scaffold only after confirmation.
- **Non-empty repo** — stack and patterns are imposed by what exists; analyze and conform, do not rewrite.
