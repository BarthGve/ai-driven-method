#!/usr/bin/env bash
# dm-witness — runs a check unless this exact content already passed it.
# Usage: dm-witness.sh <name> -- <command...>
#   bash .dm/lib/dm-witness.sh full -- npm test
# The key is the working-tree content (tracked + untracked, .gitignore respected), so staging
# or committing the same content still hits. docs/reviews and docs/plans are left out: the
# pipeline writes them between checks and no test reads them. A stamp is saved only when the
# command exits 0 and the content did not change while it ran. Exit code passes through.
set -euo pipefail

name="${1:-}"
case "$name" in ""|*[!a-z0-9-]*) echo "dm-witness: name must match [a-z0-9-]+" >&2; exit 2 ;; esac
shift
[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "usage: dm-witness.sh <name> -- <command...>" >&2; exit 2; }

key() {
  local idx tree
  idx="$(mktemp)"
  # -p keeps the index mtime: git's racy-clean check then rehashes files edited in the same second.
  cp -p "$(git rev-parse --git-path index)" "$idx" 2>/dev/null || :
  GIT_INDEX_FILE="$idx" git add -A -- . >/dev/null 2>&1
  GIT_INDEX_FILE="$idx" git rm -r -q --cached --ignore-unmatch -- docs/reviews docs/plans >/dev/null
  tree="$(GIT_INDEX_FILE="$idx" git write-tree)"
  rm -f "$idx"
  printf '%s\n%s\n' "$tree" "$*" | git hash-object --stdin
}

dir="$(git rev-parse --git-path dm-witness)"
stamp="$dir/$name"
before="$(key "$@")"

if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$before" ]; then
  echo "dm-witness: skipped '$name' — this exact content already passed it ($*)."
  exit 0
fi

rm -f "$stamp"
set +e
"$@"
code=$?
set -e

if [ "$code" -eq 0 ]; then
  if [ "$(key "$@")" = "$before" ]; then
    mkdir -p "$dir"
    echo "$before" > "$stamp"
  else
    echo "dm-witness: '$name' passed but not stamped — content changed during the run (a non-ignored output file?)." >&2
  fi
fi
exit "$code"
