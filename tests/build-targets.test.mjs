import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";

function emit(target) {
  const out = mkdtempSync(join(tmpdir(), `dm-${target}-`));
  execFileSync("node", ["bin/dm-build.mjs", "--target", target, "--src", "src", "--out", out]);
  return out;
}

test("grok emit has commands, skills, agents", () => {
  const out = emit("grok");
  assert.ok(existsSync(join(out, "commands", "dm-prd.md")));
  assert.ok(existsSync(join(out, "skills", "tdd-skill", "SKILL.md")));
  assert.ok(existsSync(join(out, "agents", "implementer.md")));
});

test("codex emit still puts commands in skills/", () => {
  const out = emit("codex");
  assert.ok(existsSync(join(out, "skills", "dm-prd", "SKILL.md")));
});

test("codex agent-skills name the skills Claude preloads", () => {
  const out = emit("codex");
  const t = readFileSync(join(out, "skills", "implementer", "SKILL.md"), "utf8");
  assert.match(t, /Load these skills first: tdd-skill, quality-bar\./);
});
