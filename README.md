# ai-driven-method

A fork of [killer-saas](https://github.com/MikeCodeur/killer-saas) by [Mike Codeur](https://github.com/MikeCodeur).

Commands: `/dm-*`.

driven keeps the original pipeline (no direct coding, file gates, subagents)
and adds: hybrid PRD (clone or greenfield), Grok install, GitHub board + wiki,
`main`/`next` flow, a stricter quality bar, and semver on release.

See [NOTICE](NOTICE) and [DOC.md](DOC.md).

A complete agentic pipeline to kill a SaaS: pick a target, cut the 20% that matters, rebuild it on your boilerplate, ship it to production.
One method = a suite of commands. One principle = no direct coding.

Small presentation or copy adjustments can use the explicit **Quick Fix**
exception when the user requests it. The primary agent edits directly, keeps the
scope narrow, and verifies the result. If the impact is architectural, business,
cross-cutting, or uncertain, the normal pipeline remains mandatory. See
[DOC.md](DOC.md#quick-fix-mode) for the complete boundary.

## Pipeline
PRD → User Stories → Stories Review → Architecture + Design System → then, per story: Research → Design → Plan → Execute → Review → Ship

![driven pipeline overview](docs/images/pipeline-overview-dark.png)

Full method documentation: [DOC.md](DOC.md)

### Framing — once per product
![Framing phase](docs/images/framing-dark.png)

### Per story — the cycle
![Per-story cycle](docs/images/story-cycle-dark.png)

## Install

You don't clone this repo into your project: the installer drops its files into whatever directory you run it from.

Quickest — choose your tool and run the matching one-liner from your project's
root (the script fetches the repo itself).

**Claude Code:**

    cd your-project
    curl -fsSL https://raw.githubusercontent.com/BarthGve/ai-driven-method/main/install.sh | bash

**Codex:**

    cd your-project
    curl -fsSL https://raw.githubusercontent.com/BarthGve/ai-driven-method/main/install.sh | bash -s -- --target codex

To install the Codex skills globally instead:

    curl -fsSL https://raw.githubusercontent.com/BarthGve/ai-driven-method/main/install.sh | bash -s -- --global --target codex

The Codex target requires Node.js and installs the skills in `.codex/skills`
for a project install or `~/.codex/skills` for a global install.

Prefer to read before you run? Clone the repo somewhere, then run the script from your project's root:

    git clone https://github.com/BarthGve/ai-driven-method.git ~/tools/ai-driven-method
    cd your-project
    ~/tools/ai-driven-method/install.sh

### Targets and scopes

One source of truth, one installer, per-tool output. Pick a **target** with `--target`, in **project** (default) or **global** (`--global`) scope:

    ./install.sh                           # Claude Code, project (default)
    ./install.sh --target codex            # Codex, project → .codex/skills + AGENTS.md
    ./install.sh --target all              # Claude + Codex, project
    ./install.sh --global                  # Claude, global (commands in every repo)
    ./install.sh --global --target codex   # Codex, global → ~/.codex/skills
    ./install.sh --global --target all     # both, global

After a global install, drop the per-project files (templates + rules) in each project:

    ~/.claude/ai-driven-method/install.sh init                 # Claude
    ~/.claude/ai-driven-method/install.sh init --target codex  # Codex

`AGENTS.md` (the rules) is shared and read natively by both tools; on Claude a one-line `CLAUDE.md` imports it. The 4 skills are the open `SKILL.md` standard, so they carry over unchanged; the 13 `dm-*` commands are emitted as Codex skills. Gemini CLI is planned next — see the fidelity matrix in [DOC.md](DOC.md).

When maintaining driven itself, edit only `src/AGENTS.md`. The root
`AGENTS.md` and `CLAUDE.md` are ignored local-install artifacts; `CLAUDE.md`
must remain a one-line `@AGENTS.md` import. See
[Editing the workflow rules](DOC.md#editing-the-workflow-rules).

### Repo-level enforcement (git hooks)

The method's guardrails don't have to depend on a specific tool's permissions. Opt in with `--hooks` to enforce them in **git**, identically for every tool:

    ./install.sh --hooks        # (add to any target)

- **pre-commit** — refuses code on a `feature/<id>` branch without a validated plan (`docs/plans/<id>.md` → `validated: yes`). Docs-only commits always pass.
- **pre-push** — refuses pushing the default branch when a merged story lacks a passed review (`docs/reviews/<id>.md` → `Ship allowed: yes`).

Reversible: `git config --unset core.hooksPath`. On Claude the harness also enforces "no direct coding" via tool permissions; the hooks make the same guarantees hold on Codex (and, later, Gemini) — enforcement lives in the repo, not the tool.

## Update

From your project's root:

    ~/tools/ai-driven-method/install.sh update              # Claude
    ~/tools/ai-driven-method/install.sh update --target codex   # Codex
    # or, without a clone:
    curl -fsSL https://raw.githubusercontent.com/BarthGve/ai-driven-method/main/install.sh | bash -s -- update
    # overwrite locally modified templates too:
    curl -fsSL https://raw.githubusercontent.com/BarthGve/ai-driven-method/main/install.sh | bash -s -- update --force

What it does — and doesn't:
- Cleanly replaces the method's tooling, tracked per target in `.dm-manifest` (`.claude/` or `.codex/` — your own commands/skills are never touched, renamed or removed files leave no ghosts).
- Refreshes the templates you haven't modified; a locally modified template is never overwritten (you get a warning instead — add `--force` to overwrite).
- Stamps the installed version in `.dm-version`.
- Never touches `AGENTS.md`: if the method's rules evolved, merge by hand.

## Usage

    /dm-prd <target-saas>
    /dm-stories
    /dm-stories-review
    /dm-architect
    /dm-design-system
    # then, per story:
    /dm-research <story>
    /dm-design <story>
    /dm-plan <story>
    /dm-execute <story>
    /dm-review <story>
    /dm-ship <story>

    # or run a story's full cycle (with human checkpoints):
    /dm-orchestrator <story>

    # where does the project stand?
    /dm-status

    # lost? pipeline map (français) :
    /dm-help

On **Codex**, the same steps run as skills (e.g. `dm-prd`, `dm-execute`) — same order, same gates. The git hooks (`--hooks`) enforce the pipeline the same way on both tools.

## Autonomous mode — `/goal`

`/goal` is a native Claude Code command (not a driven one): you state an outcome, it figures out how to reach it — planning the work, spawning parallel agents, and finding the best sequence itself. Point it at the driven commands and it drives the whole backlog for you.

    /goal All user stories planned, reviewed and executed.
    Start a dynamic workflow with multiple parallel agents to implement
    the user stories (find the best sequence).

It reads `docs/stories.md`, respects the dependency order, and fans out `/dm-research → … → /dm-review` across independent stories in parallel — while the method's gates still hold: no execution without a validated plan, no ship past an open critical. Use it to go wide once the framing (PRD, stories, architecture, design system) is done; use the individual `/dm-*` commands when you want to drive one story by hand.
