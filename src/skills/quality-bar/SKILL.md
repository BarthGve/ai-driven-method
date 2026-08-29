---
name: quality-bar
description: Security, factorization, maintainability, anti-hallucination, and severity thresholds for implementer and reviewer. Blocks ship on critical or major.
---
# Quality bar

Quality is how the plan is implemented, not extra features. Preloaded in `implementer` and `reviewer`.

## Anti-hallucination (do it, don't skim)

An agent produces plausible code. Plausible ≠ correct. Hunt the gap:

1. Run the test suite yourself. A summary claiming "tests pass" is a claim, not a fact.
2. For every import, function call, API and config key in the diff: open the target and verify it exists — exact name, exact signature, exact location. Invented references are the #1 agent failure.
3. Diff vs plan, task by task: every plan task present? anything in the diff the plan never asked for? Drift in either direction is a finding.
4. Read the tests like production code. Flag tests whose only contract is a CSS class, DOM structure, ordinary static label, prop echo or component inventory: they increase cost without protecting behavior. Then PROVE the valuable tests bite. Pick the one or two invariants the story turns on (a guard, predicate, state transition or query clause) and neutralize them: invert the condition, return the opposite constant, drop the clause. Run the suite, COUNT the red tests, then restore and prove the tree is clean (`git diff --exit-code` on the file) before writing a line of report. Report what you neutralized and how many tests went red. Zero red on a neutralized invariant means it is untested, whatever the suite's total says — that is a finding, not a detail. Presentation-only changes need browser evidence, not a forced mutation. An assertion-free test is a hallucinated safety net; an unrestored mutation is a worse defect than the one you were hunting.
5. Hunt plausible-but-wrong logic: values that look right (defaults, formats, status codes, edge conditions) but were never checked against reality.
6. Regressions: what else uses the touched code paths? Open it.

## Security (OWASP on the diff)

On every behavior-bearing change, check:

- **Injection** — untrusted input reaching SQL/commands/templates/shell without validation or parameterization.
- **Authz** — permission checks next to the rule; no missing or bypassable authorization.
- **Secrets** — no credentials, tokens, or keys in source, logs, or client bundles.
- **IDOR** — object access gated by ownership/scope, not by guessing an id.
- **XSS** — unescaped user content in HTML/attributes/URLs.
- **Sensitive logs** — no PII, secrets, or full payloads in logs.

## Factorization

- **One rule, one place** — a business rule lives once; callers invoke it, they do not re-encode it.
- Reuse research/plan anchor points; do not copy-paste an existing flow under a new name.
- Duplicate rule, duplicated flow, or rule in the wrong layer is a finding.

## Maintainability

- Small units, clear names, no dead code.
- **No speculative abstraction** — extract when the second real use arrives, not "just in case".
- Flag god functions, unjustified coupling, lying comments, and modules that cannot evolve without a rewrite.

## Tests (bite)

- Behavior-bearing work needs a test that bites (see anti-hallucination step 4).
- Decorative or duplicated tests are findings; prefer deleting them to keeping a fictional safety net.

## UI

- Design-system components and tokens only.
- Component/token/color outside the system is drift (major by default; critical if it breaks product visual coherence).

## Severity scale

Report lines (exact):

```
Max severity: <critical|major|minor|none>
Ship allowed: <yes|no>
```

- **critical** → `Ship allowed: no` — security hole, data leak, authz bypass, invented API, untested or duplicated business rule, behavior regression.
- **major** → `Ship allowed: no` — copy-paste of an existing flow, unevolvable module, plan ignored, design-system break of visual coherence (when the defect is in this diff).
- **minor** → ship allowed — style, naming, small cleanup.

**A single critical or major = `Ship allowed: no`.** Fix via `/dm-execute` (fix mode), then a new `/dm-review`.
