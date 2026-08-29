#!/usr/bin/env bash
# dm-gate — driven repo-level guardrails, enforced by git (tool-independent).
# Works the same whether the harness is Claude Code, Codex or Gemini CLI:
# the gates live in the repo, not in a tool's per-command permissions.
#
# Branches (app git flow):
#   main  = production (only updated from next; GitHub branch protection is the real guarantee)
#   next  = integration (feature PRs land here)
#   feature/<story-id>              = story framing (docs only)
#   feature/<story-id>/<ticket-id>  = ticket implementation
#
# Subcommands:
#   dm-gate plan-validated <id>              exit 0 if docs/plans/<story>.md has `validated: yes`
#   dm-gate ship-allowed  <id>               exit 0 if the review has `Ship allowed: yes`
#   dm-gate default-integration-branch       prints `next`
#   dm-gate pre-commit                       block code without a validated plan (ticket branches);
#                                            block app code on story framing branches (docs only)
#   dm-gate pre-push                         refuse non-next into main; gate ticket merges into next
set -euo pipefail

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

integration_branch() { printf 'next'; }
production_branch() { printf 'main'; }

# feature/<story-id> or feature/<story-id>/<ticket-id> → id after feature/
story_id_from_branch() {
  local branch="$1"
  case "$branch" in
    feature/*) printf '%s' "${branch#feature/}" ;;
    *) printf '' ;;
  esac
}

# s01-x/t01-y → s01-x; s01-x → s01-x (plan lives at docs/plans/<story-id>.md)
plan_id_from_work_id() {
  local id="$1"
  case "$id" in
    */*) printf '%s' "${id%%/*}" ;;
    *) printf '%s' "$id" ;;
  esac
}

# feature/<story-id>/<ticket-id> → ticket-id; framing branch → empty
ticket_id_from_branch() {
  local id; id="$(story_id_from_branch "$1")"
  case "$id" in
    */*) printf '%s' "${id#*/}" ;;
    *) printf '' ;;
  esac
}

plan_validated() {
  local id="$1" root plan_id; root="$(repo_root)"
  plan_id="$(plan_id_from_work_id "$id")"
  local f="$root/docs/plans/$plan_id.md"
  [ -f "$f" ] || { echo "dm-gate: no plan for '$plan_id' (docs/plans/$plan_id.md missing). Run /dm-plan $plan_id." >&2; return 1; }
  if grep -qE '^validated:[[:space:]]*yes[[:space:]]*$' "$f"; then
    return 0
  fi
  echo "dm-gate: plan '$plan_id' not validated (docs/plans/$plan_id.md lacks 'validated: yes'). Validate it via /dm-plan $plan_id." >&2
  return 1
}

# id may be <story-id> or <story-id>/<ticket-id> → docs/reviews/<id>.md
ship_allowed() {
  local id="$1" root; root="$(repo_root)"
  local f="$root/docs/reviews/$id.md"
  [ -f "$f" ] || { echo "dm-gate: no review for '$id' (docs/reviews/$id.md missing). Run /dm-review $id." >&2; return 1; }
  if grep -qE '^Ship allowed:[[:space:]]*yes[[:space:]]*$' "$f"; then
    return 0
  fi
  echo "dm-gate: ship blocked for '$id' (docs/reviews/$id.md is not 'Ship allowed: yes')." >&2
  return 1
}

pre_commit() {
  local branch id ticket; branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
  id="$(story_id_from_branch "$branch")"
  # Not on a feature branch → nothing to enforce here (e.g. Quick Fix on next).
  [ -n "$id" ] || return 0

  local code_staged=0 path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    case "$path" in
      docs/*) : ;;
      *) code_staged=1 ;;
    esac
  done < <(git diff --cached --name-only)
  [ "$code_staged" = 1 ] || return 0

  ticket="$(ticket_id_from_branch "$branch")"
  if [ -z "$ticket" ]; then
    echo "dm-gate: refusing code commit on $branch — story framing branches are docs-only. App code goes on feature/<story-id>/<ticket-id>." >&2
    return 1
  fi

  # Ready-gate: child Issue is identified from feature/<story-id>/<ticket-id>.
  # Full board status check (ready / in progress) lands with dm-board (ready-ok); here we
  # always require a validated story plan before ticket code commits.
  if ! plan_validated "$id"; then
    echo "dm-gate: refusing code commit on $branch — no validated plan for child '$ticket'. (docs-only commits are always allowed.)" >&2
    return 1
  fi
  return 0
}

pre_push() {
  local prod integ; prod="$(production_branch)"; integ="$(integration_branch)"
  local local_ref local_sha remote_ref remote_sha rc=0 zero="0000000000000000000000000000000000000000"
  while read -r local_ref local_sha remote_ref remote_sha; do
    [ -n "${local_ref:-}" ] || continue
    [ "$local_sha" != "$zero" ] || continue

    # Production: only next may update main. Client-side hint — GitHub protection is authoritative.
    if [ "$remote_ref" = "refs/heads/$prod" ]; then
      if [ "$local_ref" != "refs/heads/$integ" ]; then
        echo "dm-gate: refusing push to $prod from ${local_ref#refs/heads/} — only $integ may update production. (GitHub branch protection is the real guarantee for $prod.)" >&2
        rc=1
      fi
      continue
    fi

    # Integration: ticket branches need a passed review before landing on next.
    if [ "$remote_ref" = "refs/heads/$integ" ]; then
      local range id
      if printf '%s' "$remote_sha" | grep -qE '^0+$'; then
        range="$local_sha"
      else
        range="$remote_sha..$local_sha"
      fi

      case "$local_ref" in
        refs/heads/feature/*)
          id="$(story_id_from_branch "${local_ref#refs/heads/}")"
          if [ -n "$id" ] && ! ship_allowed "$id"; then
            echo "dm-gate: refusing to push $remote_ref — '$id' has no passed review." >&2
            rc=1
          fi
          ;;
      esac

      while IFS= read -r id; do
        [ -n "$id" ] || continue
        if ! ship_allowed "$id"; then
          echo "dm-gate: refusing to push $remote_ref — story/ticket '$id' was merged without a passed review." >&2
          rc=1
        fi
      done < <(git log --merges --format='%s' "$range" 2>/dev/null \
                | sed -n "s/.*Merge branch '\\(feature\\/[^']*\\)'.*/\\1/p" \
                | sed 's#^feature/##' | sort -u)
    fi
  done
  return "$rc"
}

cmd="${1:-}"
case "$cmd" in
  plan-validated)               plan_validated "${2:?story id required}" ;;
  ship-allowed)                 ship_allowed   "${2:?story or ticket id required}" ;;
  default-integration-branch)   integration_branch; printf '\n' ;;
  pre-commit)                   pre_commit ;;
  pre-push)                     pre_push ;;
  *)
    echo "usage: dm-gate {plan-validated <id>|ship-allowed <id>|default-integration-branch|pre-commit|pre-push}" >&2
    exit 2
    ;;
esac
