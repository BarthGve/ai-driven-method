# PRD — <product name>

## Mode
<clone | greenfield>

## Target SaaS
<clone only: name, URL, one-line; greenfield: "n/a — original product">

## Kill mode
<clone only: internal replacement (stop paying, own the data, fit our workflow) | competing product (sell it) — and what that implies for scope; greenfield: "n/a">

## Why kill it
<clone: what it costs, what it does badly for us, what we don't need from it; greenfield: why this product now>

## Problem
What need, for whom, why now.

## Target users
Profiles, usage context. (Clone internal replacement: the actual team. Competitor: the segment. Greenfield: the intended users.)

## Perimeter — the 20% that matters
### Replicated (core loop) / In scope
| Feature | Complexity (1-5) | Why this score |
|---|---|---|
| <feature> | <n> | <...> |

Scale: 1 trivial CRUD · 2 form + persistence + list · 3 business logic / several states · 4 integrations, payments, roles · 5 real-time, migrations, external systems. A 5 is a graveyard candidate — keep it only if it IS the core value.

### Explicitly NOT replicated (graveyard) / Out of scope
<what we deliberately drop — be exhaustive, this list kills scope creep. Used in both clone and greenfield.>

### The angle (done differently / better)
<clone: where we beat the target, beyond parity; greenfield: the differentiator>

## Constraints
Technical, time, dependencies.

## Success criteria
<clone: parity checklist on the perimeter + the angle; greenfield: measurable outcomes on in-scope features + the angle.>
