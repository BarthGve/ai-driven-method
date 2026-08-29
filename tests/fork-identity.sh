#!/usr/bin/env bash
set -euo pipefail
git remote get-url upstream | grep -q 'MikeCodeur/killer-saas'
git remote get-url origin | grep -q 'ai-driven-method'
git merge-base --is-ancestor e2b857848285b793f39091b1eb9b2b1ce15a5e87 HEAD \
  || git merge-base --is-ancestor origin/main HEAD
test -f docs/superpowers/specs/2026-08-29-driven-method-design.md
test -f src/commands/ks-prd.md -o -f src/commands/dm-prd.md
echo OK
