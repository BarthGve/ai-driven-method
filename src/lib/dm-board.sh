#!/usr/bin/env bash
# dm-board — GitHub Issues + Project V2 status helpers.
# Status labels exact: backlog | ready | in progress | test | shipped
# Parent never uses ready.
#
#   status-get <issue-key>
#   status-set <issue-key> <status>
#   issue-create-us <story-id> <title> <body-file>
#   issue-create-ticket <story-id> <ticket-id> <title> <body-file>
#   require-ready <story-id>/<ticket-id>
#   parent-sync <story-id>          (also run by every status-set on a child)
#   status-all                     → one line per driven issue on the board: <key><TAB><status>
#   issue-close <issue-key>         close the Issue (ticket at ship, story at release); status untouched
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
# shellcheck source=dm-config.sh
source "$SCRIPT_DIR/dm-config.sh"

gh_bin() { command -v gh; }

# Items of the configured Project V2 (project_id), with the configured status field
# (status_field_id). Not `gh issue list --json projectItems`: that gives the first project an
# issue belongs to and its default "Status" field, which /dm-init may not be the one in use.
# Read once per invocation (each 100 items cost one GraphQL point) and reused by every lookup.
# Safe because every command reads only after its last write (issue create and item-add
# happen before the first lookup); a command that reads, then creates, then reads again must
# empty "$DM_ITEMS_CACHE" in between.
DM_ITEMS_CACHE="$(mktemp)"
trap 'rm -f "$DM_ITEMS_CACHE"' EXIT

ITEMS_QUERY='query($id:ID!,$endCursor:String){node(id:$id){... on ProjectV2{items(first:100,after:$endCursor){totalCount pageInfo{hasNextPage endCursor} nodes{id content{... on Issue{id number title}} fieldValues(first:50){nodes{... on ProjectV2ItemFieldSingleSelectValue{name field{... on ProjectV2SingleSelectField{id}}}}}}}}}}'

# Prints [{item_id, id, number, title, status}] — id/number/title are the issue's.
# GitHub sometimes answers a short list with exit code 0 (fewer items than totalCount):
# reread a few times, then fail loudly — a short list must never read as "not found".
# A gh error (quota, network) fails at once: retrying would only spend more quota.
items_json() {
  if [ ! -s "$DM_ITEMS_CACHE" ]; then
    local n=1 attempts="${DM_BOARD_MAX_ATTEMPTS:-3}" delay="${DM_BOARD_RETRY_DELAY:-2}" pages rc
    while :; do
      pages="$("$(gh_bin)" api graphql --paginate --slurp -f id="$DM_PROJECT_ID" -f query="$ITEMS_QUERY")" || {
        echo "dm-board: project board unreadable (GraphQL error — quota? see bash .dm/lib/dm-quota.sh)" >&2
        return 3
      }
      rc=0
      node -e '
        const pages = JSON.parse(require("fs").readFileSync(0, "utf8"));
        const field = process.argv[1];
        const conn = (p) => (p.data && p.data.node && p.data.node.items) || { nodes: [], totalCount: 0 };
        const total = pages.length ? conn(pages[0]).totalCount : 0;
        const nodes = pages.flatMap((p) => conn(p).nodes);
        if (nodes.length < total) { console.error(nodes.length + "/" + total); process.exit(4); }
        const out = nodes.filter((n) => n.content && n.content.title).map((n) => {
          const v = (n.fieldValues.nodes || []).find((x) => x && x.field && x.field.id === field);
          return { item_id: n.id, id: n.content.id, number: n.content.number, title: n.content.title, status: v ? v.name : "" };
        });
        process.stdout.write(JSON.stringify(out));
      ' "$DM_STATUS_FIELD_ID" <<<"$pages" >"$DM_ITEMS_CACHE" 2>"$DM_ITEMS_CACHE.err" || rc=$?
      if [ "$rc" -eq 0 ]; then rm -f "$DM_ITEMS_CACHE.err"; break; fi
      : >"$DM_ITEMS_CACHE"
      if [ "$rc" -ne 4 ] || [ "$n" -ge "$attempts" ]; then
        echo "dm-board: project board read incomplete after $n attempts (items read/total: $(cat "$DM_ITEMS_CACHE.err")) — retry later" >&2
        rm -f "$DM_ITEMS_CACHE.err"
        return 3
      fi
      n=$((n + 1)); sleep "$delay"
    done
  fi
  cat "$DM_ITEMS_CACHE"
}

# Exact title key match: "[key] ..." or "[key]". Exit 2 = not on the board, 3 = board unreadable.
find_issue_json() {
  local key="$1" list
  list="$(items_json)" || return 3
  node -e '
    const key = process.argv[1];
    const prefix = "[" + key + "]";
    const items = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const hit = items.find((i) => i.title === prefix || i.title.startsWith(prefix + " "));
    if (!hit) process.exit(2);
    process.stdout.write(JSON.stringify(hit));
  ' "$key" <<<"$list"
}

issue_status_name() {
  local key="$1" raw rc=0
  raw="$(find_issue_json "$key")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    [ "$rc" -eq 2 ] && echo "dm-board: issue not found on the project board for key '$key'" >&2
    return 1
  fi
  node -e '
    const item = JSON.parse(process.argv[1]);
    if (!item.status) { console.error("dm-board: no project status for " + item.title); process.exit(1); }
    process.stdout.write(item.status);
  ' "$raw"
}

issue_project_item_id() {
  local raw
  raw="$(find_issue_json "$1")" || { echo "dm-board: no project item id" >&2; return 1; }
  node -e 'process.stdout.write(JSON.parse(process.argv[1]).item_id)' "$raw"
}

cmd_status_get() {
  local key="${1:-}"
  [ -n "$key" ] || { echo "usage: status-get <issue-key>" >&2; return 1; }
  dm_config_load
  issue_status_name "$key"
  printf '\n'
}

cmd_status_set() {
  local key="${1:-}" status="${2:-}"
  [ -n "$key" ] && [ -n "$status" ] || {
    echo "usage: status-set <issue-key> <status>" >&2
    return 1
  }
  case "$status" in
    backlog|ready|"in progress"|test|shipped) ;;
    *)
      echo "dm-board: invalid status '$status' (backlog|ready|in progress|test|shipped)" >&2
      return 1
      ;;
  esac
  # Parent keys never use ready
  case "$key" in
    */*) ;;
    *)
      if [ "$status" = "ready" ]; then
        echo "dm-board: parent US must not use status 'ready'" >&2
        return 1
      fi
      ;;
  esac
  dm_config_load
  local item_id option_id
  item_id="$(issue_project_item_id "$key")"
  option_id="$(dm_config_status_option_id "$status")"
  "$(gh_bin)" project item-edit \
    --id "$item_id" \
    --project-id "$DM_PROJECT_ID" \
    --field-id "$DM_STATUS_FIELD_ID" \
    --single-select-option-id "$option_id" \
    >/dev/null
  # The cached board must show this write: the parent derivation below reads it.
  node -e '
    const fs = require("fs");
    const items = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    for (const i of items) if (i.item_id === process.argv[2]) i.status = process.argv[3];
    fs.writeFileSync(process.argv[1], JSON.stringify(items));
  ' "$DM_ITEMS_CACHE" "$item_id" "$status"
  # A child's move is the parent's move: derive the US from its tickets now, not at ship only.
  case "$key" in
    */*) cmd_parent_sync "${key%%/*}" >/dev/null ||
      echo "dm-board: WARNING: '$key' set to '$status', but its parent US was not re-derived (rerun parent-sync ${key%%/*})" >&2 ;;
  esac
}

cmd_require_ready() {
  local key="${1:-}"
  [ -n "$key" ] || { echo "usage: require-ready <story-id>/<ticket-id>" >&2; return 1; }
  case "$key" in
    */*) ;;
    *)
      echo "dm-board: require-ready is child-only (got '$key')" >&2
      return 1
      ;;
  esac
  dm_config_load
  local st
  if ! st="$(issue_status_name "$key")"; then
    return 1
  fi
  case "$st" in
    ready|"in progress") return 0 ;;
    *)
      echo "dm-board: '$key' status is '$st' (need ready or in progress)" >&2
      return 1
      ;;
  esac
}

derive_parent_status() {
  # stdin: one child status per line → prints parent status
  node -e '
    const lines = require("fs").readFileSync(0, "utf8").split(/\n/).map((s) => s.trim()).filter(Boolean);
    if (!lines.length) {
      process.stdout.write("backlog");
      process.exit(0);
    }
    const all = (set) => lines.every((s) => set.has(s));
    const any = (set) => lines.some((s) => set.has(s));
    if (all(new Set(["shipped"]))) process.stdout.write("shipped");
    else if (all(new Set(["test", "shipped"]))) process.stdout.write("test");
    else if (any(new Set(["ready", "in progress", "test", "shipped"]))) process.stdout.write("in progress");
    else process.stdout.write("backlog");
  '
}

cmd_parent_sync() {
  local story="${1:-}"
  [ -n "$story" ] || { echo "usage: parent-sync <story-id>" >&2; return 1; }
  case "$story" in
    */*)
      echo "dm-board: parent-sync expects story-id only" >&2
      return 1
      ;;
  esac
  dm_config_load
  local children_statuses desired current
  children_statuses="$(
    items_json | node -e '
      const needle = "[" + process.argv[1] + "/";
      for (const i of JSON.parse(require("fs").readFileSync(0, "utf8")))
        if (i.title.startsWith(needle) && i.status) console.log(i.status);
    ' "$story"
  )" || return 1
  desired="$(printf '%s\n' "$children_statuses" | derive_parent_status)"
  if ! current="$(issue_status_name "$story" 2>/dev/null)"; then
    echo "dm-board: parent issue '$story' not found" >&2
    return 1
  fi
  if [ "$current" = "$desired" ]; then
    printf '%s\n' "$desired"
    return 0
  fi
  cmd_status_set "$story" "$desired"
  printf '%s\n' "$desired"
}

cmd_status_all() {
  dm_config_load
  local list
  list="$(items_json)" || return 1
  node -e '
    for (const i of JSON.parse(require("fs").readFileSync(0, "utf8"))) {
      const m = /^\[([^\]]+)\]/.exec(i.title);
      if (m) console.log(m[1] + "\t" + (i.status || "-"));
    }
  ' <<<"$list"
}

# Closing counts toward the parent's "Sub-issues progress" (closed / total). It never sets a
# status: driven owns the status field, and /dm-init removes the board workflow "Item closed"
# that would turn a closed ticket "shipped" while it is only on next.
cmd_issue_close() {
  local key="${1:-}" raw number
  [ -n "$key" ] || { echo "usage: issue-close <issue-key>" >&2; return 1; }
  dm_config_load
  raw="$(find_issue_json "$key")" || { echo "dm-board: issue not found on the project board for key '$key'" >&2; return 1; }
  number="$(node -e 'process.stdout.write(String(JSON.parse(process.argv[1]).number))' "$raw")"
  "$(gh_bin)" issue close "$number" -R "$(dm_config_repo)" --reason completed >/dev/null
}

extract_issue_number_from_url() {
  node -e '
    const u = process.argv[1];
    const m = u.match(/\/issues\/(\d+)/);
    if (!m) { console.error("dm-board: cannot parse issue url "+u); process.exit(1); }
    process.stdout.write(m[1]);
  ' "$1"
}

add_issue_to_project_backlog() {
  local url="$1"
  local key_guess="$2"
  local number item_id
  number="$(extract_issue_number_from_url "$url")"
  if [ -n "${DM_PROJECT_NUMBER:-}" ]; then
    if ! "$(gh_bin)" project item-add "$DM_PROJECT_NUMBER" \
      --owner "$DM_OWNER" \
      --url "$url" \
      --format json >/dev/null 2>&1; then
      echo "dm-board: item-add failed for issue #${number} (${key_guess}), retrying once" >&2
      if ! "$(gh_bin)" project item-add "$DM_PROJECT_NUMBER" \
        --owner "$DM_OWNER" \
        --url "$url" \
        --format json >/dev/null 2>&1; then
        echo "dm-board: WARNING: issue #${number} (${key_guess}) could not be added to the project board" >&2
      fi
    fi
  fi
  if item_id="$(issue_project_item_id "$key_guess" 2>/dev/null)"; then
    local option_id
    option_id="$(dm_config_status_option_id "backlog")"
    "$(gh_bin)" project item-edit \
      --id "$item_id" \
      --project-id "$DM_PROJECT_ID" \
      --field-id "$DM_STATUS_FIELD_ID" \
      --single-select-option-id "$option_id" \
      >/dev/null
  else
    echo "dm-board: WARNING: issue #${number} (${key_guess}) has no project item — not on the board" >&2
  fi
  printf '%s\n' "$number"
}

# When GitHub sub-issues are unavailable: Parent: #<n> in the body + label ticket.
fallback_parent_link() {
  local child_num="$1" parent_num="$2" body_file="$3"
  local repo tmp
  repo="$(dm_config_repo)"
  tmp="$(mktemp)"
  cat "$body_file" >"$tmp"
  if ! grep -q "^Parent: #${parent_num}$" "$tmp" 2>/dev/null; then
    printf '\n\nParent: #%s\n' "$parent_num" >>"$tmp"
  fi
  "$(gh_bin)" label create ticket -R "$repo" --force >/dev/null 2>&1 || \
    echo "dm-board: WARNING: could not ensure label 'ticket'" >&2
  if ! "$(gh_bin)" issue edit "$child_num" -R "$repo" \
    --body-file "$tmp" --add-label ticket >/dev/null; then
    echo "dm-board: WARNING: failed to write Parent: #${parent_num} on issue #${child_num}" >&2
  fi
  rm -f "$tmp"
}

cmd_issue_create_us() {
  local story_id="${1:-}" title="${2:-}" body_file="${3:-}"
  [ -n "$story_id" ] && [ -n "$title" ] && [ -n "$body_file" ] || {
    echo "usage: issue-create-us <story-id> <title> <body-file>" >&2
    return 1
  }
  [ -f "$body_file" ] || { echo "dm-board: body file missing: $body_file" >&2; return 1; }
  dm_config_load
  local full_title url
  full_title="[${story_id}] ${title}"
  url="$("$(gh_bin)" issue create -R "$(dm_config_repo)" -t "$full_title" -F "$body_file")"
  add_issue_to_project_backlog "$url" "$story_id"
}

# Adopt an Issue written by hand: rename to the driven convention, then board it.
# status-set cannot do this — it resolves an existing project item, and a
# hand-written Issue was never added to the project.
cmd_issue_adopt() {
  local key="${1:-}" number="${2:-}" title="${3:-}"
  [ -n "$key" ] && [ -n "$number" ] && [ -n "$title" ] || {
    echo "usage: issue-adopt <issue-key> <issue-number> <title>" >&2
    return 1
  }
  dm_config_load
  local repo full_title url
  repo="$(dm_config_repo)"
  full_title="[${key}] ${title}"
  "$(gh_bin)" issue edit "$number" -R "$repo" --title "$full_title" >/dev/null
  url="https://github.com/${repo}/issues/${number}"
  add_issue_to_project_backlog "$url" "$key"
}

cmd_issue_create_ticket() {
  local story_id="${1:-}" ticket_id="${2:-}" title="${3:-}" body_file="${4:-}"
  [ -n "$story_id" ] && [ -n "$ticket_id" ] && [ -n "$title" ] && [ -n "$body_file" ] || {
    echo "usage: issue-create-ticket <story-id> <ticket-id> <title> <body-file>" >&2
    return 1
  }
  [ -f "$body_file" ] || { echo "dm-board: body file missing: $body_file" >&2; return 1; }
  dm_config_load
  local key full_title url parent_raw parent_id child_num
  key="${story_id}/${ticket_id}"
  full_title="[${key}] ${title}"
  url="$("$(gh_bin)" issue create -R "$(dm_config_repo)" -t "$full_title" -F "$body_file")"
  child_num="$(add_issue_to_project_backlog "$url" "$key")"
  # Link as sub-issue when parent exists; on failure write Parent: #<n> + label ticket
  if parent_raw="$(find_issue_json "$story_id" 2>/dev/null)"; then
    parent_id="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).id||"")' "$parent_raw")"
    local parent_num child_id sub_ok=0
    parent_num="$(node -e 'process.stdout.write(String(JSON.parse(process.argv[1]).number||""))' "$parent_raw")"
    child_id="$(node -e '
      const issues=JSON.parse(require("fs").readFileSync(0,"utf8"));
      const key=process.argv[1];
      const prefix="["+key+"]";
      const hit=issues.find(i=> (i.title||"")===prefix || (i.title||"").startsWith(prefix+" "));
      process.stdout.write(hit && hit.id ? hit.id : "");
    ' "$key" <<<"$(items_json)" 2>/dev/null || true)"
    if [ -n "$parent_id" ] && [ -n "$child_id" ]; then
      if "$(gh_bin)" api graphql -f query='mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){issue{id}}}' \
        -f p="$parent_id" -f c="$child_id" >/dev/null 2>&1; then
        sub_ok=1
      fi
    fi
    if [ "$sub_ok" -eq 0 ] && [ -n "$parent_num" ]; then
      echo "dm-board: WARNING: addSubIssue failed for $key — writing Parent: #${parent_num} and label ticket" >&2
      fallback_parent_link "$child_num" "$parent_num" "$body_file"
    fi
  fi
  printf '%s\n' "$child_num"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    status-get) shift; cmd_status_get "$@" ;;
    status-set) shift; cmd_status_set "$@" ;;
    issue-create-us) shift; cmd_issue_create_us "$@" ;;
    issue-create-ticket) shift; cmd_issue_create_ticket "$@" ;;
    issue-adopt) shift; cmd_issue_adopt "$@" ;;
    require-ready) shift; cmd_require_ready "$@" ;;
    parent-sync) shift; cmd_parent_sync "$@" ;;
    status-all) shift; cmd_status_all "$@" ;;
    issue-close) shift; cmd_issue_close "$@" ;;
    *)
      echo "usage: dm-board.sh status-get|status-set|status-all|issue-close|issue-create-us|issue-create-ticket|issue-adopt|require-ready|parent-sync ..." >&2
      return 1
      ;;
  esac
}

main "$@"
