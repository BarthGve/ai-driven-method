import { execFileSync } from "node:child_process";
import {
  mkdtempSync,
  writeFileSync,
  chmodSync,
  mkdirSync,
  readFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BOARD = join(ROOT, "src/lib/dm-board.sh");
const GH_STUB = join(ROOT, "tests/fixtures/gh-stub.sh");

const CONFIG = {
  owner: "acme",
  repo: "app",
  project_id: "PVT_test",
  project_number: 1,
  status_field_id: "FIELD_status",
  status_option_ids: {
    backlog: "opt1",
    ready: "opt2",
    "in progress": "opt3",
    test: "opt4",
    shipped: "opt5",
  },
};

function appDir(issues) {
  const d = mkdtempSync(join(tmpdir(), "board-"));
  mkdirSync(join(d, ".dm"), { recursive: true });
  writeFileSync(join(d, ".dm/config.json"), JSON.stringify(CONFIG, null, 2));
  const statePath = join(d, "gh-state.json");
  writeFileSync(
    statePath,
    JSON.stringify(
      {
        issues,
        status_option_ids: CONFIG.status_option_ids,
        edits: [],
      },
      null,
      2,
    ),
  );
  const bin = join(d, "bin");
  mkdirSync(bin, { recursive: true });
  writeFileSync(join(bin, "gh"), readFileSync(GH_STUB));
  chmodSync(join(bin, "gh"), 0o755);
  chmodSync(BOARD, 0o755);
  return { d, statePath, bin };
}

function runBoard(d, bin, statePath, args) {
  return execFileSync("bash", [BOARD, ...args], {
    cwd: d,
    encoding: "utf8",
    env: {
      ...process.env,
      PATH: `${bin}:${process.env.PATH}`,
      DM_GH_STUB_STATE: statePath,
    },
  });
}

test("status-get returns ready for child issue", () => {
  const { d, statePath, bin } = appDir([
    {
      title: "[s01-x/t01-y] Persist (M, 1.5d)",
      number: 2,
      projectItems: [
        { id: "PVTI_2", status: { optionId: "opt2", name: "ready" } },
      ],
    },
  ]);
  const out = runBoard(d, bin, statePath, ["status-get", "s01-x/t01-y"]).trim();
  assert.equal(out, "ready");
});

test("require-ready succeeds for ready", () => {
  const { d, statePath, bin } = appDir([
    {
      title: "[s01-x/t01-y] Persist (M, 1.5d)",
      number: 2,
      projectItems: [
        { id: "PVTI_2", status: { optionId: "opt2", name: "ready" } },
      ],
    },
  ]);
  assert.equal(
    runBoard(d, bin, statePath, ["require-ready", "s01-x/t01-y"]).trim(),
    "",
  );
});

test("require-ready succeeds for in progress", () => {
  const { d, statePath, bin } = appDir([
    {
      title: "[s01-x/t01-y] Persist (M, 1.5d)",
      number: 2,
      projectItems: [
        { id: "PVTI_2", status: { optionId: "opt3", name: "in progress" } },
      ],
    },
  ]);
  assert.equal(
    runBoard(d, bin, statePath, ["require-ready", "s01-x/t01-y"]).trim(),
    "",
  );
});

test("require-ready fails for backlog", () => {
  const { d, statePath, bin } = appDir([
    {
      title: "[s01-x/t01-y] Persist (M, 1.5d)",
      number: 2,
      projectItems: [
        { id: "PVTI_2", status: { optionId: "opt1", name: "backlog" } },
      ],
    },
  ]);
  assert.throws(() =>
    runBoard(d, bin, statePath, ["require-ready", "s01-x/t01-y"]),
  );
});

test("require-ready fails when issue missing", () => {
  const { d, statePath, bin } = appDir([]);
  assert.throws(() =>
    runBoard(d, bin, statePath, ["require-ready", "s01-x/t01-y"]),
  );
});

test("require-ready rejects parent-only key", () => {
  const { d, statePath, bin } = appDir([
    {
      title: "[s01-x] Parent",
      number: 1,
      projectItems: [
        { id: "PVTI_1", status: { optionId: "opt2", name: "ready" } },
      ],
    },
  ]);
  assert.throws(() => runBoard(d, bin, statePath, ["require-ready", "s01-x"]));
});

test("parent-sync sets test when all children test/shipped", () => {
  const { d, statePath, bin } = appDir([
    {
      title: "[s01-x] Parent US",
      number: 1,
      projectItems: [
        { id: "PVTI_1", status: { optionId: "opt3", name: "in progress" } },
      ],
    },
    {
      title: "[s01-x/t01-a] A (S, 1d)",
      number: 2,
      projectItems: [
        { id: "PVTI_2", status: { optionId: "opt4", name: "test" } },
      ],
    },
    {
      title: "[s01-x/t02-b] B (M, 1.5d)",
      number: 3,
      projectItems: [
        { id: "PVTI_3", status: { optionId: "opt5", name: "shipped" } },
      ],
    },
  ]);
  runBoard(d, bin, statePath, ["parent-sync", "s01-x"]);
  const state = JSON.parse(readFileSync(statePath, "utf8"));
  const parent = state.issues.find((i) => i.number === 1);
  assert.equal(parent.projectItems[0].status.name, "test");
});
