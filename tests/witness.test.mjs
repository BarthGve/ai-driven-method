import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const WITNESS = join(ROOT, "src/lib/dm-witness.sh");

function repo() {
  const d = mkdtempSync(join(tmpdir(), "dm-witness-"));
  const git = (...a) => execFileSync("git", a, { cwd: d, stdio: "pipe" });
  git("init", "-q", "-b", "main");
  git("config", "user.email", "t@t");
  git("config", "user.name", "t");
  writeFileSync(join(d, ".gitignore"), "runs.log\nnode_modules/\n");
  writeFileSync(join(d, "a.js"), "1\n");
  git("add", "-A");
  git("commit", "-qm", "init");
  return { d, git };
}

// The check appends a line to runs.log (ignored) so we can count real executions.
const witness = (d, cmd = "echo run >> runs.log") =>
  spawnSync("bash", [WITNESS, "full", "--", "bash", "-c", cmd], { cwd: d, encoding: "utf8" });
const runs = (d) => (existsSync(join(d, "runs.log")) ? readFileSync(join(d, "runs.log"), "utf8").split("\n").filter(Boolean).length : 0);

test("same content hits, even after staging and committing it", () => {
  const { d, git } = repo();
  writeFileSync(join(d, "a.js"), "2\n"); // unstaged edit
  assert.equal(witness(d).status, 0);
  git("add", "-A");
  git("commit", "-qm", "ticket");
  const r = witness(d);
  assert.equal(r.status, 0);
  assert.match(r.stdout, /skipped 'full'/);
  assert.equal(runs(d), 1);
});

test("pipeline docs and ignored files do not invalidate the stamp", () => {
  const { d, git } = repo();
  witness(d);
  mkdirSync(join(d, "docs/reviews/s01"), { recursive: true });
  writeFileSync(join(d, "docs/reviews/s01/t01.md"), "Ship allowed: yes\n");
  mkdirSync(join(d, "node_modules"));
  writeFileSync(join(d, "node_modules/x.js"), "x\n");
  witness(d);
  git("add", "-A");
  git("commit", "-qm", "review");
  witness(d);
  assert.equal(runs(d), 1);
});

test("a tracked edit or a new untracked file reruns", () => {
  const { d } = repo();
  witness(d);
  writeFileSync(join(d, "a.js"), "3\n");
  witness(d);
  writeFileSync(join(d, "b.js"), "new\n");
  witness(d);
  assert.equal(runs(d), 3);
});

test("a different command is a different key", () => {
  const { d } = repo();
  witness(d);
  witness(d, "echo run >> runs.log; true");
  assert.equal(runs(d), 2);
});

test("a failure keeps its exit code and leaves no stamp", () => {
  const { d } = repo();
  assert.equal(witness(d, "echo run >> runs.log; exit 3").status, 3);
  assert.equal(witness(d, "echo run >> runs.log; exit 3").status, 3);
  assert.equal(runs(d), 2);
});

test("content changed during the run is not stamped", () => {
  const { d } = repo();
  const r = witness(d, "echo run >> runs.log; echo changed > a.js");
  assert.match(r.stderr, /not stamped/);
  witness(d, "echo run >> runs.log");
  assert.equal(runs(d), 2);
});

test("a name outside [a-z0-9-] is refused", () => {
  const { d } = repo();
  const r = spawnSync("bash", [WITNESS, "../x", "--", "true"], { cwd: d, encoding: "utf8" });
  assert.equal(r.status, 2);
});
