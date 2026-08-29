import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

test("prd template has hybrid mode", () => {
  const t = readFileSync("src/templates/prd.md", "utf8");
  assert.match(t, /greenfield/i);
  assert.match(t, /clone|Target SaaS/i);
  assert.doesNotMatch(t, /<< IP Mike/);
});

test("prd command asks clone vs greenfield first", () => {
  const t = readFileSync("src/commands/dm-prd.md", "utf8");
  assert.match(t, /greenfield/i);
});

test("skills have no empty IP placeholders", () => {
  for (const p of [
    "src/skills/agentic-stories/SKILL.md",
    "src/skills/codebase-analysis/SKILL.md",
    "src/skills/tdd-skill/SKILL.md",
    "src/skills/stories-review/SKILL.md",
  ]) {
    assert.doesNotMatch(readFileSync(p, "utf8"), /<< IP Mike/);
  }
});
