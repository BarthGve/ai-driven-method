import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";

test("command files are dm- prefixed", () => {
  const names = readdirSync("src/commands").filter((f) => f.endsWith(".md"));
  assert.ok(names.length >= 13);
  for (const n of names) assert.match(n, /^dm-/);
});

test("install.sh points at the fork and dm paths", () => {
  const t = readFileSync("install.sh", "utf8");
  assert.match(t, /BarthGve\/ai-driven-method/);
  assert.match(t, /\.dm-manifest/);
  assert.doesNotMatch(t, /MikeCodeur\/killer-saas\.git/);
  assert.doesNotMatch(t, /\.ks-manifest/);
});

test("dm-build emits claude command dm-prd", () => {
  const out = mkdtempSync(join(tmpdir(), "dm-build-"));
  execFileSync("node", ["bin/dm-build.mjs", "--target", "claude", "--src", "src", "--out", out]);
  assert.ok(existsSync(join(out, "commands", "dm-prd.md")));
});
