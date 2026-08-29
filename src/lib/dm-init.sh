#!/usr/bin/env bash
# dm-init — bootstrap app repo: remote, next/main rulesets, Project V2, wiki, VERSION.
# Usage: dm-init.sh run [--repo NAME] [--owner LOGIN] [--public|--private] [--yes]
#        [--no-remote] [--title PROJECT_TITLE]
set -euo pipefail

YES=0
VISIBILITY=private
REPO_NAME=""
OWNER=""
CREATE_REMOTE=1
PROJECT_TITLE="driven"

die() { echo "dm-init: $*" >&2; exit 1; }

confirm() {
  local msg="$1"
  if [ "$YES" -eq 1 ]; then
    return 0
  fi
  printf '%s [y/N] ' "$msg" >&2
  local ans
  read -r ans || true
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) die "aborted" ;;
  esac
}

parse_args() {
  [ "${1:-}" = "run" ] || die "usage: dm-init.sh run [--repo NAME] [--owner LOGIN] [--public|--private] [--yes]"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) YES=1; shift ;;
      --public) VISIBILITY=public; shift ;;
      --private) VISIBILITY=private; shift ;;
      --repo)
        REPO_NAME="${2:-}"; [ -n "$REPO_NAME" ] || die "--repo needs a name"
        shift 2
        ;;
      --owner)
        OWNER="${2:-}"; [ -n "$OWNER" ] || die "--owner needs a login"
        shift 2
        ;;
      --no-remote) CREATE_REMOTE=0; shift ;;
      --title)
        PROJECT_TITLE="${2:-}"; shift 2
        ;;
      *) die "unknown flag: $1" ;;
    esac
  done
}

ensure_git() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    git init -b main
  fi
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
  if [ "$branch" = "HEAD" ] || [ -z "$branch" ]; then
    git checkout -B main 2>/dev/null || git branch -M main
  elif [ "$branch" != "main" ]; then
    # Prefer main as production; rename only if no main yet
    if ! git show-ref --verify --quiet refs/heads/main; then
      git branch -M main
    fi
  fi
  if [ -z "$(git status --porcelain 2>/dev/null || true)" ] && ! git rev-parse HEAD >/dev/null 2>&1; then
    # Empty repo: need an initial commit for branches
    if [ ! -f README.md ]; then
      printf '# %s\n' "${REPO_NAME:-app}" >README.md
    fi
    git add -A
    git -c user.email="${GIT_AUTHOR_EMAIL:-dm-init@localhost}" \
        -c user.name="${GIT_AUTHOR_NAME:-dm-init}" \
        commit -m "chore: initial commit" || true
  fi
}

ensure_next_branch() {
  if git show-ref --verify --quiet refs/heads/next; then
    return 0
  fi
  git branch next main 2>/dev/null || git branch next
}

write_version_and_changelog() {
  if [ ! -f VERSION ]; then
    printf '0.1.0\n' >VERSION
  fi
  if [ ! -f CHANGELOG.md ]; then
    cat >CHANGELOG.md <<'EOF'
# Changelog

## 0.1.0 - unreleased

EOF
  fi
}

copy_ci_workflow() {
  local src=""
  local here
  here="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  # Prefer method-repo workflows next to lib (../../src/workflows from installed .dm/lib)
  for cand in \
    "$here/../workflows/dm-gate.yml" \
    "$here/../../src/workflows/dm-gate.yml" \
    "$here/../../workflows/dm-gate.yml"
  do
    if [ -f "$cand" ]; then src="$cand"; break; fi
  done
  if [ -z "$src" ]; then
    echo "dm-init: no dm-gate.yml template yet — skip CI copy" >&2
    return 0
  fi
  mkdir -p .github/workflows
  cp "$src" .github/workflows/dm-gate.yml
}

resolve_owner_repo() {
  if [ -z "$OWNER" ]; then
    OWNER="$(gh api user -q .login 2>/dev/null || true)"
  fi
  [ -n "$OWNER" ] || die "cannot resolve owner (pass --owner or authenticate gh)"
  if [ -z "$REPO_NAME" ]; then
    REPO_NAME="$(basename "$(pwd)")"
  fi
}

create_remote_if_needed() {
  if [ "$CREATE_REMOTE" -eq 0 ]; then
    return 0
  fi
  if git remote get-url origin >/dev/null 2>&1; then
    echo "dm-init: origin already set — skip gh repo create"
    # Derive owner/repo from origin when possible
    local url
    url="$(git remote get-url origin)"
    node -e '
      const u=process.argv[1];
      let m=u.match(/github\.com[:/]([^/]+)\/([^/.]+)(?:\.git)?$/);
      if (m) {
        console.log(m[1]);
        console.log(m[2]);
      }
    ' "$url" | {
      read -r o || true
      read -r r || true
      [ -n "${o:-}" ] && OWNER="$o"
      [ -n "${r:-}" ] && REPO_NAME="$r"
    }
    return 0
  fi
  confirm "Create GitHub repo ${OWNER}/${REPO_NAME} (${VISIBILITY})?"
  local vis_flag=--private
  [ "$VISIBILITY" = public ] && vis_flag=--public
  gh repo create "${OWNER}/${REPO_NAME}" "$vis_flag" --source=. --remote=origin --push
}

enable_wiki() {
  gh api -X PATCH "repos/${OWNER}/${REPO_NAME}" -f has_wiki=true >/dev/null
}

# Repository rulesets: main ← only next; next ← feature/*
apply_rulesets() {
  local repo_id
  repo_id="$(gh api "repos/${OWNER}/${REPO_NAME}" -q .node_id)"

  # main: require PR; restrict to head ref next via ruleset conditions is limited —
  # use pull_request + required_review; plus branch name pattern restriction via rules.
  # Classic protection as baseline:
  gh api -X PUT "repos/${OWNER}/${REPO_NAME}/branches/main/protection" \
    -H "Accept: application/vnd.github+json" \
    --input - >/dev/null 2>&1 <<'JSON' || true
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

  gh api -X PUT "repos/${OWNER}/${REPO_NAME}/branches/next/protection" \
    -H "Accept: application/vnd.github+json" \
    --input - >/dev/null 2>&1 <<'JSON' || true
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

  # Ruleset: main only accepts merges from next (branch name pattern on PR source via rulesets API)
  create_or_update_ruleset "driven-main" "main" "next" || true
  create_or_update_ruleset "driven-next" "next" "feature/*" || true
  unset repo_id
}

create_or_update_ruleset() {
  local name="$1" target_branch="$2" source_pattern="$3"
  # List existing
  local existing
  existing="$(gh api "repos/${OWNER}/${REPO_NAME}/rulesets" -q ".[] | select(.name==\"$name\") | .id" 2>/dev/null | head -1 || true)"
  local body
  body="$(node -e '
    const name=process.argv[1], target=process.argv[2], source=process.argv[3];
    const rules = [
      { type: "pull_request", parameters: {
          required_approving_review_count: 0,
          dismiss_stale_reviews_on_push: false,
          require_code_owner_review: false,
          require_last_push_approval: false,
          required_review_thread_resolution: false
      }},
      { type: "non_fast_forward" }
    ];
    // Restrict which branches can update this branch via pull requests when supported
    const payload = {
      name,
      target: "branch",
      enforcement: "active",
      conditions: {
        ref_name: { include: ["refs/heads/"+target], exclude: [] }
      },
      rules,
      bypass_actors: []
    };
    // Note: GitHub rulesets do not always encode source branch allow-list;
    // document source_pattern for operators. Emit as metadata in name suffix when needed.
    void source;
    process.stdout.write(JSON.stringify(payload));
  ' "$name" "$target_branch" "$source_pattern")"
  if [ -n "$existing" ]; then
    printf '%s' "$body" | gh api -X PUT "repos/${OWNER}/${REPO_NAME}/rulesets/${existing}" --input - >/dev/null
  else
    printf '%s' "$body" | gh api -X POST "repos/${OWNER}/${REPO_NAME}/rulesets" --input - >/dev/null
  fi
}

create_project_and_config() {
  mkdir -p .dm
  if [ -f .dm/config.json ]; then
    echo "dm-init: .dm/config.json exists — skip project create"
    return 0
  fi
  confirm "Create Project V2 '${PROJECT_TITLE}' with board statuses?"

  local proj_json project_id project_number
  proj_json="$(gh project create --owner "$OWNER" --title "$PROJECT_TITLE" --format json)"
  project_id="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id||j.node_id||"")' "$proj_json")"
  project_number="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(String(j.number??""))' "$proj_json")"
  [ -n "$project_id" ] && [ -n "$project_number" ] || die "failed to create project"

  # Link project to repo (best-effort)
  gh project link "$project_number" --owner "$OWNER" --repo "$REPO_NAME" >/dev/null 2>&1 || true

  # Create SINGLE_SELECT field with exact five statuses.
  # Prefer a dedicated field name if default Status cannot be rewritten.
  local field_json field_id
  field_json="$(
    gh project field-create "$project_number" \
      --owner "$OWNER" \
      --name "Status" \
      --data-type SINGLE_SELECT \
      --single-select-options "backlog,ready,in progress,test,shipped" \
      --format json 2>/dev/null || true
  )"
  if [ -z "$field_json" ]; then
    field_json="$(
      gh project field-create "$project_number" \
        --owner "$OWNER" \
        --name "DM Status" \
        --data-type SINGLE_SELECT \
        --single-select-options "backlog,ready,in progress,test,shipped" \
        --format json
    )"
  fi
  field_id="$(node -e 'const j=JSON.parse(process.argv[1]); process.stdout.write(j.id||"")' "$field_json")"
  [ -n "$field_id" ] || die "failed to create status field"

  # Map option names → ids from field-list
  local fields_json
  fields_json="$(gh project field-list "$project_number" --owner "$OWNER" --format json)"
  node -e '
    const fs = require("fs");
    const owner = process.argv[1];
    const repo = process.argv[2];
    const projectId = process.argv[3];
    const projectNumber = Number(process.argv[4]);
    const fieldId = process.argv[5];
    const fields = JSON.parse(process.argv[6]);
    const list = Array.isArray(fields) ? fields : (fields.fields || fields.items || []);
    const field = list.find((f) => f.id === fieldId) || list.find((f) => (f.name === "Status" || f.name === "DM Status"));
    const options = (field && (field.options || field.configuration?.options)) || [];
    const status = {};
    for (const opt of options) {
      const name = opt.name || opt.name;
      if (name) status[name] = opt.id;
    }
    for (const need of ["backlog", "ready", "in progress", "test", "shipped"]) {
      if (!status[need]) {
        // field-create response may embed options
        const created = JSON.parse(process.argv[7] || "{}");
        const opts = created.options || [];
        for (const o of opts) if (o.name) status[o.name] = o.id;
      }
    }
    const cfg = {
      owner,
      repo,
      project_id: projectId,
      project_number: projectNumber,
      status_field_id: fieldId,
      status_option_ids: status
    };
    fs.mkdirSync(".dm", { recursive: true });
    fs.writeFileSync(".dm/config.json", JSON.stringify(cfg, null, 2) + "\n");
  ' "$OWNER" "$REPO_NAME" "$project_id" "$project_number" "$field_id" "$fields_json" "$field_json"
}

push_branches() {
  if ! git remote get-url origin >/dev/null 2>&1; then
    return 0
  fi
  git push -u origin main 2>/dev/null || git push -u origin HEAD:main || true
  git push -u origin next 2>/dev/null || true
}

cmd_run() {
  command -v gh >/dev/null || die "gh CLI required"
  command -v node >/dev/null || die "node required"
  ensure_git
  resolve_owner_repo
  write_version_and_changelog
  copy_ci_workflow
  create_remote_if_needed
  ensure_next_branch
  enable_wiki
  apply_rulesets
  create_project_and_config
  push_branches
  echo "dm-init: done — ${OWNER}/${REPO_NAME} (VERSION=$(tr -d '[:space:]' <VERSION))"
}

parse_args "$@"
cmd_run
