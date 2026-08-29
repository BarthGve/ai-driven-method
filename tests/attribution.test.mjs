import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

test("NOTICE credits Mike Codeur and the fork", () => {
  const t = readFileSync("NOTICE", "utf8");
  assert.match(t, /Mike Codeur|MikeCodeur/);
  assert.match(t, /killer-saas/);
  assert.match(t, /fork/i);
});

test("README credits upstream and names driven", () => {
  const t = readFileSync("README.md", "utf8");
  assert.match(t, /https:\/\/github.com\/MikeCodeur\/killer-saas/);
  assert.match(t, /ai-driven-method/);
  assert.match(t, /Mike Codeur/);
});

test("README uses a text pipeline and a manual smoke note", () => {
  const t = readFileSync("README.md", "utf8");
  assert.doesNotMatch(t, /docs\/images\//);
  assert.doesNotMatch(t, /\/ks-/);
  assert.match(t, /\/dm-prd/);
  assert.match(t, /\/dm-init/);
  assert.match(t, /\/dm-release/);
  assert.match(t, /feature\/<story-id>\/<ticket-id>/);
  assert.match(t, /Manual smoke/);
  assert.match(t, /throwaway/);
});
