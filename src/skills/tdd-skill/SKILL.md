---
name: tdd-skill
description: Test-first discipline for agentic implementation. Preloaded in the implementer subagent.
---
# Agentic TDD

For each task in the plan:
1. Write a failing test that describes the expected behavior.
2. Run it and watch it fail. This step is not optional: a test you never saw fail proves nothing.
3. Write the minimum code to make it pass.
4. Run the suite. Refactor if needed, tests always green.
5. Tick the task's checkbox in the plan. No commit here.

Rules:
- No production code without a test motivating it.
- Test behavior, not implementation: assert what the user gets, not which internal function got called.
- Minimal scope: YAGNI. Implement the task, nothing more.
- One commit per story, not per task, tests green at commit. It carries the code of every task and the plan file with its checkboxes ticked — the plan is the live progress tracker, never a commit trigger.

## Where the value is

Not every layer deserves the same effort. Ranked, and the ranking is not negotiable:

1. **Business rules — this is where the suite earns its keep.** Validation, permissions, the decisions that make the product refuse or accept. Cover every actor the rule distinguishes, and on every refusal assert BOTH that it was refused AND that nothing was written or read further down. A refusal that still reaches the data layer is a leak, not a refusal.
2. **Pure functions** — derivations, validators, orderings, parsers. Cheap, precise, they pin the invariants. Extract a rule into a pure function *so that it can be tested this way*: a rule buried in a screen or a request handler is a rule you will end up testing badly.
3. **Persistence shape and schema changes** — the queries actually emitted, and the constraints that carry a business rule. Production depends on these and usually nothing else guards them.
4. **Screens** — only the behavior a user can observe: what appears, what is refused, what an interaction produces. Never the markup.

## Where a rule is proven is not a free choice

**A rule is proven where it lives.**

Tests at the edges — request handlers, actions, controllers — routinely replace the layer underneath with a double. The real rule is then never executed, so such a test proves the plumbing (status, shape, parameters) and *nothing about the rule*, however much it looks like it does.

Never write, and never accept, the reasoning "the endpoint is tested, therefore the rule is tested". If a story adds a rule, the test that proves it sits beside the rule. One edge test for the plumbing is enough.

## The cost model the suite actually pays

Runtime is dominated by **per-file** cost — environment setup and module loading — not by the number of assertions. In a mature suite the assertions are a small fraction of the wall clock; preparing an environment for each file is most of it. Measure it once on the project before optimising anything: the breakdown usually surprises.

Two consequences:

- **One test file per unit under test, never one per behavior.** Adding a case to an existing file is nearly free; creating a file is not. When you catch yourself creating a second file for the same unit, add a group inside the first one instead.
- **The heavy environment only where it is needed.** Test runners that simulate a browser pay that cost per file. A file that never renders anything and never touches browser globals must run in the light environment. Most tests of rules, queries and pure functions belong there.

## The acceptance criterion is the mutation, not the count

Before ticking a task: **neutralize the line you just protected and watch the right test go red.** Remove the guard, invert the condition, return early — then run.

- Nothing goes red → the test is decorative. Delete it and write the one that bites, or state in your report that this behavior is untested.
- The wrong test goes red → the coverage is accidental. Move the assertion to where the rule lives.

Restore the mutation immediately, and state in your summary which mutations you ran and how many tests each turned red. A story that cannot name a single biting mutation has not been tested, whatever its test count says.

## Do not write these

They cost real time and catch nothing:

- **Inventory tests** freezing a list of constants against a literal copy of itself. They go red on every legitimate addition and catch no defect.
- **Substring coverage** of documentation or registries: an entry whose name is contained in a longer one is "covered" by that other one, and the guarantee is an illusion.
- **Mock echo**: asserting a double was called with exactly what the test just handed it. That tests the double.
- **Snapshots of markup**, and any assertion on class names or DOM structure.
- **A test written to raise a coverage number.** This method sets no coverage target, deliberately: that metric is what manufactures suites that are large, slow and blind.

## Budget

A story adds **at most two new test files**. Beyond that, fold the cases into existing files. If a story genuinely needs more, say so in your report with the reason — it is a signal the story is too big, exactly like a plan growing past ten tasks.

## Failure modes — and what to do

- The new test passes immediately → it doesn't test the new behavior. Rewrite the test, not the code.
- The tests can't run (broken setup, missing runner) → stop and report. Never "skip testing just this once".
- The test is flaky (passes and fails across runs) → fix the flakiness before moving on; a flaky test guards nothing.
- The task is untestable as written → the plan is wrong at that point. Stop and report; don't improvise.
- The behavior is only reachable through a replaced boundary → you are about to write a test that cannot fail. Push the rule down into a unit you can test directly, and test it there.

<< IP Mike: test runner and commands, environment names, layer vocabulary, the actors a rule must distinguish, naming and file layout of test files. >>
