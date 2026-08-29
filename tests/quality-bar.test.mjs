import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

test("quality-bar skill exists and blocks major", () => {
  const t = readFileSync("src/skills/quality-bar/SKILL.md", "utf8");
  assert.match(t, /major/);
  assert.match(t, /Ship allowed: no/);
  assert.match(t, /security/i);
  assert.match(t, /factori[sz]ation|duplicat/i);
});

test("reviewer preloads quality-bar", () => {
  const t = readFileSync("src/agents/reviewer.md", "utf8");
  assert.match(t, /quality-bar/);
});

test("review checklist includes security and factorization", () => {
  const t = readFileSync("src/templates/review-checklist.md", "utf8");
  assert.match(t, /Security/i);
  assert.match(t, /Factor/i);
});
