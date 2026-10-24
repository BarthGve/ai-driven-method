// Every shipped file, command, agent and skill the prose names must exist. A rename
// otherwise breaks the pipeline at run time while every other test stays green.
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";

const walk = (d) =>
  readdirSync(d).flatMap((f) => (statSync(join(d, f)).isDirectory() ? walk(join(d, f)) : [join(d, f)]));
const PROSE = [...walk("src").filter((f) => f.endsWith(".md")), "README.md", "DOC.md"];

function missing(re, exists) {
  const out = [];
  for (const f of PROSE) {
    for (const m of readFileSync(f, "utf8").matchAll(re)) {
      if (!exists(m[1])) out.push(`${f}: ${m[0]}`);
    }
  }
  return [...new Set(out)];
}

test("templates/<file> names a shipped template", () => {
  assert.deepEqual(missing(/templates\/([\w.-]+\.md)/g, (n) => existsSync(join("src/templates", n))), []);
});

test(".dm/lib/<script> names a shipped script", () => {
  assert.deepEqual(missing(/\.dm\/lib\/([\w.-]+\.sh)/g, (n) => existsSync(join("src/lib", n))), []);
});

test("/dm-<command> names a shipped command", () => {
  // Not preceded by a path character: `.dm/lib/dm-x.sh` and `/tmp/dm-x` are not commands.
  assert.deepEqual(missing(/(?<![\w./-])\/(dm-[a-z-]+)\b(?![.\w/])/g, (n) => existsSync(`src/commands/${n}.md`)), []);
});

test("subagent_type names a shipped agent", () => {
  assert.deepEqual(missing(/subagent_type:\s*([\w-]+)/g, (n) => existsSync(`src/agents/${n}.md`)), []);
});

test("preloaded skills exist", () => {
  const bad = [];
  for (const f of walk("src/agents")) {
    const fm = readFileSync(f, "utf8").split("---")[1] ?? "";
    for (const m of fm.matchAll(/^\s+-\s+([\w-]+)$/gm)) {
      if (!existsSync(`src/skills/${m[1]}/SKILL.md`)) bad.push(`${f}: ${m[1]}`);
    }
  }
  assert.deepEqual(bad, []);
});

test("every command, skill and agent says when to use it and when not", () => {
  const files = [...walk("src/commands"), ...walk("src/skills").filter((f) => f.endsWith("SKILL.md")), ...walk("src/agents")];
  const bad = files.filter((f) => {
    const d = readFileSync(f, "utf8").match(/^description: (.*)$/m)?.[1] ?? "";
    return !/(Use |À utiliser).*(Not for|Pas pour)/.test(d);
  });
  assert.deepEqual(bad, []);
});
