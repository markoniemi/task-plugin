# task — a Claude Code plugin

A backlog-to-branch task protocol. A human writes down what should happen; the agent
plans it, implements it on a branch with unit tests; the human verifies the plan,
reads the diff and merges.

This repository is both the plugin and its marketplace.

## Install

```
/plugin marketplace add markoniemi/task-plugin
/plugin install task@task-plugin
```

Installing at user scope makes it available in every project on the machine. During
development, `claude --plugin-dir <path-to-this-clone>` loads it straight from disk,
and `claude plugin validate .` checks the manifests.

A repository of your own is a third-party marketplace, which an employer can
restrict or block through managed settings. Check that before depending on the
install line above at work; `--plugin-dir` against a local clone still works when
marketplaces are blocked, at the cost of updating by hand.

## Commands

| Command | What it does |
| :- | :- |
| `/task:init` | Set `docs/tasks/` up in a project that has no backlog yet. Run it first; it changes nothing if the backlog is already there. |
| `/task:task [name-of-task]` | Start, continue or finish the named task. With no name, states the protocol and lists the tasks. |
| `/task:next-task` | Take the next open backlog entry: highest priority, then first in `Tasks.md`. |
| `/task:clean-tasks` | Delete the `done` and `cancelled` tasks and their backlog entries, one commit each. Only when you ask. |

The protocol itself — the task file shape, the statuses and the transitions — is
`skills/task/SKILL.md`.

## What a project using the plugin keeps

```
docs/tasks/Tasks.md          the backlog: one heading per task idea
docs/tasks/<slug>.md         one file per task: frontmatter, description, plan
docs/tasks/README.md         the pipeline, explained for humans
```

No `AGENTS.md` and no stub: the rules come from the plugin.

A backlog entry is a heading plus a short explanation, with the status and the
priority in brackets:

```markdown
### feature: move Tasks to docs/tasks [draft, high]

Move the task directory from `Tasks/` to `docs/tasks/` so all documentation
lives under `docs/`.
```

The word before the colon is the **kind** — `feature`, `bug` or `task`, and no
prefix means `task`. It decides what the branch is called, `feature/<slug>`,
`bug/<slug>` or `task/<slug>`, and nothing else.

Statuses: `draft` → `planning` → `planned` → `in_progress` → `in_review` →
`approved` → `done`, with `changes_requested` back to `in_review`. A human moves
`draft` → `planning`, verifies the plan at `planned`, reviews the diff at
`in_review` and merges at `approved`; the agent does the rest. Priorities are
`high`, `medium` and `low`.

`cancelled` is the other terminal status: the work will not happen, or it happened
and was reverted — Jira's `Done` with the resolution `Won't Do`, GitHub's *closed
as not planned*. A human sets it, from any status but `done`, and nothing comes
back out of it. The agent then deletes the task's branch if it was never merged,
and leaves commits already on `main` alone rather than reverting them.

**Whether a plan is required is the status, not the kind.** `planning` asks for
one. Setting `planned` yourself, with no plan in the task file, waives it and the
agent goes straight to the code. Either way `planned` means cleared to implement,
and review at `in_review` is a human's for every kind.

## Configuration

The plugin asks for three values when you enable it, and `/config` shows them:

| Key | Default | What it decides |
| :- | :- | :- |
| `create_branch` | `true` | A task may have its own branch. Off: every task is committed on `main`. |
| `create_pull_request` | `false` | Reaching `in_review` pushes the branch and opens a pull request on GitHub, or a merge request on GitLab. The host then does the merging. |
| `squash_on_merge` | `true` | Merging a task branch squashes it into one commit on `main`, with a message written to your project's own conventions. Off: the merge is a fast-forward. |

Those answers are per user, so a project states its own in YAML frontmatter at the
top of its `docs/tasks/Tasks.md`, which wins over them:

```markdown
---
create_branch: true
create_pull_request: false
squash_on_merge: true
---
```

The first two are ceilings, not defaults: `create_branch: false` means no task
gets a branch, and nothing per task overrides it. `create_pull_request: true`
needs `create_branch: true`, plus `gh` or `glab` authenticated for the `origin`
remote; the plugin picks the tool from that remote.

`squash_on_merge` governs only the merge the agent runs itself — a task branch
with no request. With no branch nothing is merged, and with a request the host
merges, squashes and deletes by its own repository settings.

The squashed commit's message is not templated: the agent writes it as it writes
any commit in your repository, describing the change rather than naming the task.
State a format in your own `CLAUDE.md` or `AGENTS.md` if you want one — this
plugin does not impose one, so it cannot drift from yours.

## Tests

```
powershell -File tests/Test-Plugin.ps1
```

Plain PowerShell, no Pester. It checks the two manifests, the four skills'
frontmatter, that the protocol's statuses and rules survived, that no `AGENTS.md` is
left behind, and that `claude plugin validate` passes.

It prints failures and a totals line, and nothing else: the agent is what runs it,
and a list of passing cases tells it nothing it can act on. `-Detailed` prints
every case under its section heading, which is what CI runs and what a human
watching a run wants.

The same command runs on every push and pull request, from
`.github/workflows/build.yml`, on a Windows runner because the suite is Windows
PowerShell 5.1. The build installs nothing and needs no API key: nothing in the
suite calls a model, and the `claude plugin validate` case skips itself when the
CLI is absent, which on a runner it is.

## Decisions

Five decisions taken after the work had been planned out, so the reasoning is
worth more than the conclusion.

**No documentation of its own.** `skills/task/SKILL.md` is the single source of
truth, this file explains the plugin to a human, and `skills/init/templates/` is
what a new project gets. A separate manual would be a second place saying the same
things with nothing keeping the two in step. Where drift would be expensive,
`tests/Test-Plugin.ps1` guards it instead of a page asking people to remember.

**No subagent per task.** A session cannot clear itself - no skill, hook or plugin
can clear the context it runs in - so delegating to a subagent is the only way to
give a task a fresh window. It was declined because the saving is not what it looks
like: `/task:task` injects the whole protocol into the session before any delegation
could happen, so the agent reads it a second time and the total spend rises.
Delegation buys more tasks per session, not cheaper tasks. Reopening this means
first splitting the protocol out of the skill a human invokes.

If parallel agents are ever genuinely wanted, the answer is not to grow them here.
[`backlog.so`](https://backlog.so/) (`osmove/backlog`, Apache-2.0) is this same
decision taken the other way, with the machinery that makes it safe: exclusive
file-scope claims, a git worktree per sub-task, a pre-commit hook that refuses a
commit no claim covers, and a scheduler that recovers crashed runs. A plugin made
of prose cannot have any of that.

**Keeps the name `task`.** Renaming to `backlog` would free the word `task` to
name a *kind* of work, which is the one real argument for it. It was declined:
"Backlog" already names three shipped products - `backlog.so`, Backlog.md and
Nulab's Backlog - and the npm name is taken, so the rename buys a crowded,
less searchable name. The repository name is also the marketplace address, so a
rename breaks `/plugin marketplace add markoniemi/task-plugin` and every install.
The vocabulary collision is paid in this plugin's own prose instead: a **task
file** is the container, whatever kind it holds, and the kind is always written in
backticks - a `task`.

Worth knowing while comparing: [Backlog.md](https://github.com/MrLesk/Backlog.md)
keeps markdown tasks in the repository much as this does, and arrived
independently at the same three human checkpoints - review the spec, review the
plan, review the code. It differs in being a binary to install, with a kanban UI
and an MCP server, where this is prose a skill injects.

**No third bracket field.** The brackets stay `[<status>, <priority>]` and the kind
goes in the heading, before a colon. A kind is a permanent fact about what the work
is, where the brackets hold what changes as it moves, so putting it there would
have been the wrong home. A prefix also stays out of the file and branch names - it
is stripped before the slug is derived - and reads as part of the sentence a human
is writing anyway.

**Prose length is a cost, and an uneven one.** `skills/task/SKILL.md` is read on
every invocation, and the other three skills open by telling the agent to read it,
so every word in it is paid again each time. These two `README.md` files are read
by people, rarely, and their cost is drift instead - several files tell the
configuration story and only `tests/Test-Plugin.ps1` keeps them in step. So
shrinking the protocol buys tokens and de-duplicating the READMEs buys correctness,
and they are not the same job. When shortening either, **cut duplication, not
explanation**: the sentences giving reasons are there because the bare rule was
misapplied first.

## This repository's own backlog

`docs/tasks/` is this project's backlog, kept here on purpose: the plugin is
developed with itself.

## Licence

MIT.
