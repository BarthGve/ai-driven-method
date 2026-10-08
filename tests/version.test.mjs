import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SCRIPT = join(ROOT, "src/lib/dm-version.sh");

test("bump minor 0.1.0 -> 0.2.0", () => {
  const d = mkdtempSync(join(tmpdir(), "ver-"));
  writeFileSync(join(d, "VERSION"), "0.1.0\n");
  chmodSync(SCRIPT, 0o755);
  const out = execFileSync("bash", [SCRIPT, "bump", "minor"], {
    cwd: d,
    encoding: "utf8",
  }).trim();
  assert.equal(out, "0.2.0");
  assert.equal(readFileSync(join(d, "VERSION"), "utf8").trim(), "0.2.0");
});

test("current prints VERSION", () => {
  const d = mkdtempSync(join(tmpdir(), "ver-"));
  writeFileSync(join(d, "VERSION"), "1.2.3\n");
  chmodSync(SCRIPT, 0o755);
  const out = execFileSync("bash", [SCRIPT, "current"], {
    cwd: d,
    encoding: "utf8",
  }).trim();
  assert.equal(out, "1.2.3");
});

test("bump syncs package.json and CHANGELOG when present", () => {
  const d = mkdtempSync(join(tmpdir(), "ver-"));
  writeFileSync(join(d, "VERSION"), "0.1.0\n");
  writeFileSync(join(d, "package.json"), '{"name":"app","version":"0.1.0"}\n');
  writeFileSync(join(d, "CHANGELOG.md"), "# Changelog\n\n");
  chmodSync(SCRIPT, 0o755);
  const out = execFileSync("bash", [SCRIPT, "bump", "patch"], {
    cwd: d,
    encoding: "utf8",
  }).trim();
  assert.equal(out, "0.1.1");
  const pkg = JSON.parse(readFileSync(join(d, "package.json"), "utf8"));
  assert.equal(pkg.version, "0.1.1");
  const log = readFileSync(join(d, "CHANGELOG.md"), "utf8");
  assert.match(log, /^## 0\.1\.1 - \d{4}-\d{2}-\d{2}/m);
});

test("bump opens the changelog section below the intro, above the previous release", () => {
  const d = mkdtempSync(join(tmpdir(), "ver-"));
  writeFileSync(join(d, "VERSION"), "0.1.0\n");
  writeFileSync(join(d, "CHANGELOG.md"), "# Changelog\n\nIntro line.\n\n## 0.1.0 - 2026-01-01\n\n- old\n");
  execFileSync("bash", [SCRIPT, "bump", "patch"], { cwd: d, encoding: "utf8" });
  const log = readFileSync(join(d, "CHANGELOG.md"), "utf8");
  assert.ok(log.indexOf("Intro line.") < log.indexOf("## 0.1.1"), "intro must stay first");
  assert.ok(log.indexOf("## 0.1.1") < log.indexOf("## 0.1.0"), "new section above previous");
});

test("driven itself carries a VERSION and a matching changelog entry", () => {
  const v = readFileSync(join(ROOT, "VERSION"), "utf8").trim();
  assert.match(v, /^\d+\.\d+\.\d+$/);
  assert.match(readFileSync(join(ROOT, "CHANGELOG.md"), "utf8"), new RegExp(v.replace(/\./g, "\\.")));
});
