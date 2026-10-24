#!/usr/bin/env bash
# dm-witness — runs a check unless this exact content already passed it.
# Usage: dm-witness.sh <name> -- <command...>
#   bash .dm/lib/dm-witness.sh full -- npm test
# The key is the working-tree content (tracked + untracked, .gitignore respected), so staging
# or committing the same content still hits. docs/reviews and docs/plans are left out: the
# pipeline writes them between checks and no test reads them. A stamp is saved only when the
# command exits 0 and the content did not change while it ran; otherwise the paths the run
# changed are named, since every later phase would rerun the check. Exit code passes through.
set -euo pipefail

name="${1:-}"
case "$name" in ""|*[!a-z0-9-]*) echo "dm-witness: name must match [a-z0-9-]+" >&2; exit 2 ;; esac
shift
[ "${1:-}" = "--" ] && shift
[ $# -gt 0 ] || { echo "usage: dm-witness.sh <name> -- <command...>" >&2; exit 2; }

# Tree of the working-tree content as the check sees it.
tree() {
  local idx t
  idx="$(mktemp)"
  # -p keeps the index mtime: git's racy-clean check then rehashes files edited in the same second.
  cp -p "$(git rev-parse --git-path index)" "$idx" 2>/dev/null || :
  GIT_INDEX_FILE="$idx" git add -A -- . >/dev/null 2>&1
  GIT_INDEX_FILE="$idx" git rm -r -q --cached --ignore-unmatch -- docs/reviews docs/plans >/dev/null
  t="$(GIT_INDEX_FILE="$idx" git write-tree)"
  rm -f "$idx"
  echo "$t"
}
key() { printf '%s\n%s\n' "$1" "$cmd" | git hash-object --stdin; }

dir="$(git rev-parse --git-path dm-witness)"
stamp="$dir/$name"
cmd="$*"
tree_before="$(tree)"
before="$(key "$tree_before")"

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
  tree_after="$(tree)"
  if [ "$tree_after" = "$tree_before" ]; then
    mkdir -p "$dir"
    echo "$before" > "$stamp"
  else
    {
      echo "dm-witness: WARNING '$name' passed but was NOT stamped — the run changed these paths:"
      git diff-tree -r --name-only "$tree_before" "$tree_after" | sed 's/^/  /'
      echo "Every later phase will rerun '$name'. Fix: add the generated ones to .gitignore; report any source file the check rewrote."
    } >&2
  fi
fi
exit "$code"
