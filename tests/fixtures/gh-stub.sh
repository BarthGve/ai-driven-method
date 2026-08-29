#!/bin/sh
# Canned gh for board-parse tests. Reads DM_GH_STUB_STATE (JSON file).
# state shape:
# {
#   "issues": [
#     {"title":"[s01-x/t01-y] Foo","number":2,"id":"I_child",
#      "projectItems":[{"id":"PVTI_child","status":{"optionId":"opt2","name":"ready"}}]},
#     {"title":"[s01-x] Parent","number":1,"id":"I_parent",
#      "projectItems":[{"id":"PVTI_parent","status":{"optionId":"opt1","name":"backlog"}}]}
#   ]
# }
set -eu
STATE="${DM_GH_STUB_STATE:-}"
if [ -z "$STATE" ] || [ ! -f "$STATE" ]; then
  echo "gh-stub: DM_GH_STUB_STATE missing" >&2
  exit 99
fi

# Flatten args for matching
args="$*"

case "$args" in
  *"issue list"*)
    node -e '
      const s=JSON.parse(require("fs").readFileSync(process.env.DM_GH_STUB_STATE,"utf8"));
      const issues=(s.issues||[]).map(i=>({
        title:i.title, number:i.number, id:i.id||("I_"+i.number),
        projectItems:i.projectItems||[]
      }));
      process.stdout.write(JSON.stringify(issues));
    '
    ;;
  *"project item-edit"*)
    # Record last edit into state.edits[]
    node -e '
      const fs=require("fs");
      const s=JSON.parse(fs.readFileSync(process.env.DM_GH_STUB_STATE,"utf8"));
      const argv=process.argv.slice(1);
      const get=flag=>{const i=argv.indexOf(flag); return i>=0?argv[i+1]:null;};
      s.edits=s.edits||[];
      s.edits.push({
        id:get("--id"),
        projectId:get("--project-id"),
        fieldId:get("--field-id"),
        optionId:get("--single-select-option-id")
      });
      // Update matching projectItems status name from option map
      const opt=get("--single-select-option-id");
      const map=s.status_option_ids||s.config_status||{};
      let name=null;
      for (const [k,v] of Object.entries(map)) if (v===opt) name=k;
      for (const issue of s.issues||[]) {
        for (const pi of issue.projectItems||[]) {
          if (pi.id===get("--id") && name) {
            pi.status={optionId:opt, name};
          }
        }
      }
      fs.writeFileSync(process.env.DM_GH_STUB_STATE, JSON.stringify(s,null,2));
    ' "$@"
    echo '{"ok":true}'
    ;;
  *"issue create"*)
    node -e '
      const fs=require("fs");
      const s=JSON.parse(fs.readFileSync(process.env.DM_GH_STUB_STATE,"utf8"));
      const argv=process.argv.slice(1);
      const get=flag=>{const i=argv.indexOf(flag); return i>=0?argv[i+1]:null;};
      const title=get("-t")||get("--title")||"untitled";
      const n=(s.issues||[]).reduce((m,i)=>Math.max(m,i.number||0),0)+1;
      const issue={
        title,
        number:n,
        id:"I_"+n,
        projectItems:[{id:"PVTI_"+n, status:{optionId:"opt1", name:"backlog"}}]
      };
      s.issues=s.issues||[];
      s.issues.push(issue);
      fs.writeFileSync(process.env.DM_GH_STUB_STATE, JSON.stringify(s,null,2));
      process.stdout.write("https://github.com/acme/app/issues/"+n+"\n");
    ' "$@"
    ;;
  *"project item-add"*)
    echo '{"id":"PVTI_added"}'
    ;;
  *"api graphql"*|*"api graphql"*)
    echo '{}'
    ;;
  *)
    echo "gh-stub: unhandled: $args" >&2
    exit 98
    ;;
esac
