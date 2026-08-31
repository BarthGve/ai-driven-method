---
description: Frame the product — clone or greenfield, perimeter, the WHAT and the WHY
argument-hint: <target SaaS or product idea>
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
---
You are framing a driven project. Subject: $ARGUMENTS

Use this template as the output structure:
@templates/prd.md

driven supports three product modes: clone an existing SaaS, greenfield an original product, or brownfield — a project whose code already runs. Before anything else, lock the mode.

Proceed as follows:
1. AskUserQuestion first — one question at a time:
   - **Mode: clone, greenfield, or brownfield?** If `docs/onboarding.md` exists, propose brownfield by default. Otherwise: if $ARGUMENTS clearly names a SaaS, confirm clone; if it is a product idea with no target, confirm greenfield. Do not skip this question.
2. Then the matching question set (still one at a time):

   **If clone:**
   - Target: which SaaS are we killing? (name, URL). If $ARGUMENTS names it, confirm it.
   - Kill mode: internal replacement (stop paying, own the data, fit our workflow) or competing product (sell it)? The whole scope depends on this answer.
   - Why: what does the target cost, what does it do badly for us, what do we not need from it?
   - Perimeter: we never clone the whole SaaS. Which core loop delivers the real value for OUR case — the 20% that matters? And what stays explicitly out (the graveyard: enterprise features, edge-case admin, integrations nobody uses)?
   - Complexity: score each replicated feature 1-5 (scale in the template). A 4-5 must earn its place — the default home of heavy features is the graveyard.
   - The angle: what do we do differently or better, beyond parity?
   - Then the classic frame: need, target users, constraints, success criteria. Success = parity on the perimeter + the angle, measurable.

   **If greenfield:**
   - Need: what problem, for whom, why now?
   - Target users: profiles and usage context.
   - In / out of scope: which features are in the first shippable product (score each 1-5), and what stays explicitly out — the graveyard still kills scope creep. No fake “target SaaS”.
   - Kill mode and Target SaaS sections: write `n/a` (greenfield / original product).
   - The angle: what is the differentiator?
   - Constraints and success criteria: measurable outcomes on in-scope features + the angle.

   **If brownfield:**
   - Read `docs/onboarding.md` first: the value loop, the users and the shipped baseline are already recorded and confirmed. Do not ask again what it answers — confirm it in one question.
   - Need and target users: pre-fill from the onboarding baseline, ask only for what is missing.
   - In / out of scope: the shipped baseline is **in** by definition. Score the remaining features 1-5; the graveyard still kills scope creep on what has not been built.
   - Kill mode and Target SaaS sections: write `n/a` (brownfield / existing product).
   - The angle: what does the next phase change or improve, beyond what already ships?
   - Constraints and success criteria: measurable outcomes on the features still to build.

3. Fill each section of the template with my answers. Fill nothing you haven't validated with me.
4. Write the result to `docs/prd.md` and commit it on the default branch (docs: prd).

End with: "PRD ready in docs/prd.md. Next step: /dm-init"
