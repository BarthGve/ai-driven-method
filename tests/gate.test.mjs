import { execFileSync, execSync } from "node:child_process";
import { mkdtempSync, writeFileSync, mkdirSync, chmodSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

const GATE = join(dirname(fileURLToPath(import.meta.url)), "..", "src/hooks/dm-gate.sh");
const AGENTS = join(dirname(fileURLToPath(import.meta.url)), "..", "src/AGENTS.md");

function repo() {
  const d = mkdtempSync(join(tmpdir(), "dm-gate-"));
  execSync("git init -b main && git config user.email t@t && git config user.name t", {
    cwd: d,
    stdio: "pipe",
  });
  writeFileSync(join(d, "README"), "x");
  execSync("git add README && git commit -m i", { cwd: d, stdio: "pipe" });
  execSync("git branch next", { cwd: d, stdio: "pipe" });
  return d;
}

function runGate(cwd, args, opts = {}) {
  chmodSync(GATE, 0o755);
  return execFileSync("bash", [GATE, ...args], {
    cwd,
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
    input: opts.input ?? "",
  });
}

test("plan-validated fails without file", () => {
  const d = repo();
  assert.throws(() => runGate(d, ["plan-validated", "s01-x"]));
});

test("plan-validated passes with validated: yes", () => {
  const d = repo();
  mkdirSync(join(d, "docs/plans"), { recursive: true });
  writeFileSync(join(d, "docs/plans/s01-x.md"), "---\nvalidated: yes\n---\n");
  assert.equal(runGate(d, ["plan-validated", "s01-x"]), "");
});

test("ship-allowed fails without review", () => {
  const d = repo();
  assert.throws(() => runGate(d, ["ship-allowed", "s01-x"]));
});

test("ship-allowed fails when Ship allowed: no", () => {
  const d = repo();
  mkdirSync(join(d, "docs/reviews"), { recursive: true });
  writeFileSync(
    join(d, "docs/reviews/s01-x.md"),
    "Max severity: critical\nShip allowed: no\n",
  );
  assert.throws(() => runGate(d, ["ship-allowed", "s01-x"]));
});

test("ship-allowed passes with Ship allowed: yes", () => {
  const d = repo();
  mkdirSync(join(d, "docs/reviews"), { recursive: true });
  writeFileSync(
    join(d, "docs/reviews/s01-x.md"),
    "Max severity: none\nShip allowed: yes\n",
  );
  assert.equal(runGate(d, ["ship-allowed", "s01-x"]), "");
});

test("ship-allowed accepts ticket review path", () => {
  const d = repo();
  mkdirSync(join(d, "docs/reviews/s01-x"), { recursive: true });
  writeFileSync(
    join(d, "docs/reviews/s01-x/t01-y.md"),
    "Max severity: none\nShip allowed: yes\n",
  );
  assert.equal(runGate(d, ["ship-allowed", "s01-x/t01-y"]), "");
});

test("default-integration-branch prints next", () => {
  const d = repo();
  const out = runGate(d, ["default-integration-branch"]).trim();
  assert.equal(out, "next");
});

test("pre-push refuses non-next push into main", () => {
  const d = repo();
  execSync("git checkout -b feature/s01-x/t01-y", { cwd: d, stdio: "pipe" });
  writeFileSync(join(d, "code.js"), "1");
  execSync("git add code.js && git commit -m feat", { cwd: d, stdio: "pipe" });
  const sha = execSync("git rev-parse HEAD", { cwd: d, encoding: "utf8" }).trim();
  const zero = "0000000000000000000000000000000000000000";
  const input = `refs/heads/feature/s01-x/t01-y ${sha} refs/heads/main ${zero}\n`;
  assert.throws(() => runGate(d, ["pre-push"], { input }));
});

test("pre-push allows next into main", () => {
  const d = repo();
  execSync("git checkout next", { cwd: d, stdio: "pipe" });
  writeFileSync(join(d, "release.txt"), "1");
  execSync("git add release.txt && git commit -m release", { cwd: d, stdio: "pipe" });
  const sha = execSync("git rev-parse HEAD", { cwd: d, encoding: "utf8" }).trim();
  const zero = "0000000000000000000000000000000000000000";
  const input = `refs/heads/next ${sha} refs/heads/main ${zero}\n`;
  assert.equal(runGate(d, ["pre-push"], { input }), "");
});

test("pre-push allows framing feature branch into next without review", () => {
  const d = repo();
  execSync("git checkout -b feature/s01-x next", { cwd: d, stdio: "pipe" });
  mkdirSync(join(d, "docs/research"), { recursive: true });
  writeFileSync(join(d, "docs/research/s01-x.md"), "research");
  execSync("git add docs && git commit -m research", { cwd: d, stdio: "pipe" });
  const sha = execSync("git rev-parse HEAD", { cwd: d, encoding: "utf8" }).trim();
  const zero = "0000000000000000000000000000000000000000";
  const input = `refs/heads/feature/s01-x ${sha} refs/heads/next ${zero}\n`;
  assert.equal(runGate(d, ["pre-push"], { input }), "");
});

test("pre-push refuses ticket feature branch into next without Ship allowed", () => {
  const d = repo();
  execSync("git checkout -b feature/s01-x/t01-y next", { cwd: d, stdio: "pipe" });
  writeFileSync(join(d, "code.js"), "1");
  execSync("git add code.js && git commit -m feat", { cwd: d, stdio: "pipe" });
  const sha = execSync("git rev-parse HEAD", { cwd: d, encoding: "utf8" }).trim();
  const zero = "0000000000000000000000000000000000000000";
  const input = `refs/heads/feature/s01-x/t01-y ${sha} refs/heads/next ${zero}\n`;
  assert.throws(() => runGate(d, ["pre-push"], { input }));
});

test("pre-push allows ticket feature branch into next with Ship allowed", () => {
  const d = repo();
  mkdirSync(join(d, "docs/reviews/s01-x"), { recursive: true });
  writeFileSync(
    join(d, "docs/reviews/s01-x/t01-y.md"),
    "Max severity: none\nShip allowed: yes\n",
  );
  execSync("git checkout -b feature/s01-x/t01-y next", { cwd: d, stdio: "pipe" });
  writeFileSync(join(d, "code.js"), "1");
  execSync("git add code.js docs && git commit -m feat", { cwd: d, stdio: "pipe" });
  const sha = execSync("git rev-parse HEAD", { cwd: d, encoding: "utf8" }).trim();
  const zero = "0000000000000000000000000000000000000000";
  const input = `refs/heads/feature/s01-x/t01-y ${sha} refs/heads/next ${zero}\n`;
  assert.equal(runGate(d, ["pre-push"], { input }), "");
});

test("AGENTS.md names next as integration and Quick Fix on next", () => {
  const t = readFileSync(AGENTS, "utf8");
  assert.match(t, /\bnext\b[\s\S]*integration|integration[\s\S]*\bnext\b/i);
  assert.match(t, /Quick Fix[\s\S]*\bnext\b/i);
  assert.doesNotMatch(t, /Quick Fix work happens only[\s\S]*on branch\s*`dev`/);
  assert.match(t, /critical or major|critical\s*\*\*or\*\*\s*major/i);
});
