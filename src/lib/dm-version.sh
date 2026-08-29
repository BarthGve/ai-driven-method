#!/usr/bin/env bash
# dm-version — read/bump VERSION; sync package.json / pyproject.toml; changelog heading.
# Usage:
#   dm-version.sh current
#   dm-version.sh bump major|minor|patch
set -euo pipefail

version_file() { printf 'VERSION'; }

read_version() {
  local f
  f="$(version_file)"
  if [ ! -f "$f" ]; then
    echo "dm-version: VERSION missing" >&2
    return 1
  fi
  tr -d '[:space:]' <"$f"
}

write_version() {
  printf '%s\n' "$1" >"$(version_file)"
}

bump_semver() {
  local ver="$1" part="$2"
  node -e '
    const [maj, min, pat] = process.argv[1].split(".").map((n) => parseInt(n, 10));
    if ([maj, min, pat].some((n) => Number.isNaN(n))) {
      console.error("dm-version: invalid VERSION "+process.argv[1]);
      process.exit(1);
    }
    const part = process.argv[2];
    let a = maj, b = min, c = pat;
    if (part === "major") { a += 1; b = 0; c = 0; }
    else if (part === "minor") { b += 1; c = 0; }
    else if (part === "patch") { c += 1; }
    else {
      console.error("dm-version: bump expects major|minor|patch");
      process.exit(1);
    }
    process.stdout.write(`${a}.${b}.${c}`);
  ' "$ver" "$part"
}

sync_package_json() {
  local ver="$1"
  [ -f package.json ] || return 0
  node -e '
    const fs = require("fs");
    const p = JSON.parse(fs.readFileSync("package.json", "utf8"));
    if (!Object.prototype.hasOwnProperty.call(p, "version")) process.exit(0);
    p.version = process.argv[1];
    fs.writeFileSync("package.json", JSON.stringify(p, null, 2) + "\n");
  ' "$ver"
}

sync_pyproject() {
  local ver="$1"
  [ -f pyproject.toml ] || return 0
  node -e '
    const fs = require("fs");
    let t = fs.readFileSync("pyproject.toml", "utf8");
    const ver = process.argv[1];
    // [project] version = "x.y.z" (first match under [project] preferred via simple replace)
    const re = /(^\[project\][\s\S]*?^version\s*=\s*")([^"]+)(")/m;
    if (re.test(t)) {
      t = t.replace(re, `$1${ver}$3`);
      fs.writeFileSync("pyproject.toml", t);
      process.exit(0);
    }
    const re2 = /^version\s*=\s*"[^"]+"/m;
    if (re2.test(t)) {
      t = t.replace(re2, `version = "${ver}"`);
      fs.writeFileSync("pyproject.toml", t);
    }
  ' "$ver"
}

append_changelog() {
  local ver="$1"
  [ -f CHANGELOG.md ] || return 0
  local day
  day="$(date -u +%Y-%m-%d)"
  local heading="## ${ver} - ${day}"
  if grep -qF "$heading" CHANGELOG.md 2>/dev/null; then
    return 0
  fi
  node -e '
    const fs = require("fs");
    const heading = process.argv[1];
    let t = fs.readFileSync("CHANGELOG.md", "utf8");
    if (t.startsWith("# ")) {
      const nl = t.indexOf("\n");
      const title = nl >= 0 ? t.slice(0, nl + 1) : t + "\n";
      const rest = nl >= 0 ? t.slice(nl + 1).replace(/^\n*/, "") : "";
      t = title + "\n" + heading + "\n\n" + rest;
    } else {
      t = heading + "\n\n" + t;
    }
    fs.writeFileSync("CHANGELOG.md", t);
  ' "$heading"
}

cmd_current() {
  read_version
  printf '\n'
}

cmd_bump() {
  local part="${1:-}"
  case "$part" in
    major|minor|patch) ;;
    *)
      echo "usage: dm-version.sh bump major|minor|patch" >&2
      return 1
      ;;
  esac
  local cur new
  cur="$(read_version)"
  new="$(bump_semver "$cur" "$part")"
  write_version "$new"
  sync_package_json "$new"
  sync_pyproject "$new"
  append_changelog "$new"
  printf '%s\n' "$new"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    current) cmd_current ;;
    bump) shift; cmd_bump "${1:-}" ;;
    *)
      echo "usage: dm-version.sh current|bump major|minor|patch" >&2
      return 1
      ;;
  esac
}

main "$@"
