import { existsSync, readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

const required = [
  "dm-prd", "dm-init", "dm-stories", "dm-stories-review", "dm-architect",
  "dm-design-system", "dm-research", "dm-design", "dm-plan", "dm-docs",
  "dm-execute", "dm-review", "dm-ship", "dm-release", "dm-orchestrator",
  "dm-status", "dm-help", "dm-continue",
];

test("all dv commands exist", () => {
  for (const n of required) {
    assert.ok(existsSync(`src/commands/${n}.md`), n);
  }
});

test("stories creates parent US only", () => {
  assert.match(readFileSync("src/commands/dm-stories.md", "utf8"), /issue-create-us/);
});

test("plan creates child tickets with size and person-day estimates", () => {
  const t = readFileSync("src/commands/dm-plan.md", "utf8");
  assert.match(t, /issue-create-ticket/);
  assert.match(t, /estimate/i);
  assert.match(t, /size/i);
  assert.match(t, /XS|S|M|L|XL/);
  assert.match(t, /0\.5/);
});

test("research does not require ready", () => {
  assert.doesNotMatch(readFileSync("src/commands/dm-research.md", "utf8"), /require-ready/);
});

test("execute requires child ready", () => {
  assert.match(readFileSync("src/commands/dm-execute.md", "utf8"), /require-ready/);
});

test("review and ship require child ready", () => {
  assert.match(readFileSync("src/commands/dm-review.md", "utf8"), /require-ready/);
  assert.match(readFileSync("src/commands/dm-ship.md", "utf8"), /require-ready/);
});

test("prd next step is dm-init", () => {
  const t = readFileSync("src/commands/dm-prd.md", "utf8");
  assert.match(t, /Next step: \/dm-init/);
  assert.doesNotMatch(t, /Next step: \/dm-stories/);
});

test("release tags main SHA, refuses double bump, documents squash-merge", () => {
  const t = readFileSync("src/commands/dm-release.md", "utf8");
  assert.match(t, /git fetch origin main/);
  assert.match(t, /git rev-parse origin\/main/);
  assert.match(t, /git tag "v\$\{ver\}" "\$main_sha"/);
  assert.match(t, /already in flight/);
  assert.match(t, /squash-merge|pr merge --squash/i);
});

test("ship sets test status", () => {
  assert.match(readFileSync("src/commands/dm-ship.md", "utf8"), /status-set .*test/);
});

test("release bumps version and wiki", () => {
  const t = readFileSync("src/commands/dm-release.md", "utf8");
  assert.match(t, /dm-version\.sh bump/);
  assert.match(t, /dm-wiki\.sh publish/);
});

test("continue is read-only on the board and writes onboarding.md", () => {
  const t = readFileSync("src/commands/dm-continue.md", "utf8");
  assert.match(t, /docs\/onboarding\.md/);
  assert.doesNotMatch(t, /require-ready/);
  assert.doesNotMatch(t, /issue-create-us|issue-create-ticket|status-set/);
});

test("continue is fail-closed on an empty repo and on an already-framed project", () => {
  const t = readFileSync("src/commands/dm-continue.md", "utf8");
  assert.match(t, /STOP/);
  assert.match(t, /docs\/prd\.md/);
});

test("continue hands off to dm-prd", () => {
  assert.match(readFileSync("src/commands/dm-continue.md", "utf8"), /Next step: \/dm-prd/);
});

test("prd offers a brownfield mode fed by onboarding.md", () => {
  const t = readFileSync("src/commands/dm-prd.md", "utf8");
  assert.match(t, /brownfield/i);
  assert.match(t, /docs\/onboarding\.md/);
});

test("stories adopts an issue mapped by onboarding.md, with confirmation", () => {
  const t = readFileSync("src/commands/dm-stories.md", "utf8");
  assert.match(t, /docs\/onboarding\.md/);
  assert.match(t, /issue-create-us/);
  assert.match(t, /issue-adopt/);
  assert.match(t, /confirm/i);
});

test("status and help route an existing project to dm-continue", () => {
  assert.match(readFileSync("src/commands/dm-status.md", "utf8"), /\/dm-continue/);
  assert.match(readFileSync("src/commands/dm-help.md", "utf8"), /\/dm-continue/);
});
