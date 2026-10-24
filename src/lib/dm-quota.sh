#!/usr/bin/env bash
# dm-quota — GitHub API quota left for this account, GraphQL (board, gh pr/issue) and REST.
# The quota is per user: every gh session, tool and app on the account draws from it.
# Reading it costs nothing. Usage: dm-quota.sh
set -euo pipefail
gh api rate_limit --jq '
  def line(n; r): "\(n): \(r.remaining)/\(r.limit) left, \(r.used) used, reset in \(((r.reset - now) / 60) | ceil) min";
  line("graphql"; .resources.graphql), line("rest"; .resources.core)'
