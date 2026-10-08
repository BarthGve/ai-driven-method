#!/usr/bin/env bash
# dm-port — stable port for tool-launched servers/tests, never the developer's dev port.
# Usage: dm-port.sh [offset]   → prints a port in 20000-29999 derived from the working directory.
# Same worktree → same port; two worktrees → different ports (offset: extra service in one worktree).
set -euo pipefail
off="${1:-0}"
case "$off" in ""|*[!0-9]*) echo "dm-port: offset must be a non-negative integer" >&2; exit 1 ;; esac
sum="$(printf '%s' "$(pwd -P)" | cksum | cut -d' ' -f1)"
echo $(( 20000 + (sum + 10#$off) % 10000 ))
