# AI Task Factory

This directory holds the tasks processed by the automated AI developer engine. A
human writes down what should happen; the AI plans it and implements it on a
branch; the human verifies the plan, reads the diff and merges.

* `Tasks.md` — the backlog: one heading per task idea.
* `<slug>.md` — one file per task, with its status and its implementation plan.

A project gets this directory, with `Tasks.md` and this file, from `/task:init`.

The rules the AI follows are not in this directory: they come from the `task`
plugin, as its `task` skill. **The rules live there, not here.** See the
repository's top-level `README.md` for installing the plugin.

## Adding a task

Add a heading plus a short explanation to `Tasks.md`:

```markdown
### move Tasks to docs/tasks [draft, high]

Move the task directory from `Tasks/` to `docs/tasks/` so all documentation
lives under `docs/`.
```

The heading becomes the task file's name: lower-cased, with `-` for every run of
anything else, so `move Tasks to docs/tasks` becomes `move-tasks-to-docs-tasks.md`.
Keep headings short and plain; the AI stops and asks you to edit one it cannot turn
into a file name.

The brackets hold the status and the priority. Then ask the AI to start that task by
name — `/task:task move Tasks to docs/tasks` — or to take the next one —
`/task:next-task`. The AI creates the task file, links it under the heading, and
keeps the brackets up to date from then on:

```markdown
### feature: move Tasks to docs/tasks [done, high]

file: [move-tasks-to-docs-tasks.md](move-tasks-to-docs-tasks.md)

Move the task directory from `Tasks/` to `docs/tasks/` so all documentation
lives under `docs/`.
```

Edit the brackets yourself to re-prioritise a task or to ask for planning; the AI
reads the change back into the task file.

## Kinds

A word before a colon in the heading says what kind of work it is:

| Kind | Branch |
| :- | :- |
| `feature:` | `feature/<slug>` |
| `bug:` | `bug/<slug>` |
| `task:` | `task/<slug>` |

**No prefix means `task`.** The prefix is dropped before the file name is made, so
`feature: move Tasks to docs/tasks` still gives `move-tasks-to-docs-tasks.md`. A
word before a colon that is not one of the three — `fix: parser crash` — is just
part of the title.

Naming the branch is all a kind does. It does not decide whether there is a plan,
and it does not decide whether there is a branch at all: that is `create_branch`
below. The branch itself is created at the first commit, so a task that writes no
code never makes one.

## Configuration

The top of `Tasks.md` carries this project's answers, as YAML frontmatter:

```markdown
---
create_branch: true
create_pull_request: false
squash_on_merge: true
---
```

| Key | Default | What it decides |
| :- | :- | :- |
| `create_branch` | `true` | A task may have its own branch. Off: everything is committed on `main`. |
| `create_pull_request` | `false` | Reaching `in_review` opens a pull request on GitHub, or a merge request on GitLab, instead of leaving the branch to be read locally. On: the host does the merging, and the AI only checks that it happened. |
| `squash_on_merge` | `true` | Merging a task branch squashes it into one commit on `main`, named after the backlog heading. Off: the merge is a fast-forward and every commit of the task stays. |

The first two are ceilings rather than defaults: `create_branch: false` takes the
branch away from every task, whatever else is written down. Omit a key and the
value falls back to your own answer in `/config`, then to the default above. The
AI reads these keys itself; edit them and the next task follows them.

`squash_on_merge` reaches only the merge the AI performs itself. With
`create_branch: false` nothing is merged, and with `create_pull_request: true`
GitHub or GitLab merges, squashes and deletes the branch by that repository's own
settings. In both cases the key changes nothing.

`create_pull_request: true` needs `create_branch: true`, and it needs `gh` or
`glab` on `PATH` and authenticated for the `origin` remote.

## Pipeline

```
Tasks.md entry ──► draft ──► planning ──► planned ──► in_progress ──► in_review ──► approved ──► done
                     │                                                    │  ▲
                     │                                                    ▼  │
                     │                                             changes_requested
                     └───────────────── any status but done ──────────────────► cancelled
```

A **human** moves `draft` → `planning`, verifies the plan at `planned`, reviews the
branch diff at `in_review`, and merges at `approved`. The AI does the rest. The
plugin's `task` skill is what it does in each step.

**Cancelling.** `cancelled` is the other end of the pipeline: the work will not
happen, or it happened and was reverted. It is yours to set, from any status but
`done`, and nothing comes back out of it — change your mind and you set the status
back by hand. The AI never cancels a task itself. Picking a cancelled one up, it
deletes the branch the task made if that branch was never merged, and leaves
anything already committed on `main` exactly where it is: it names those commits
and stops. Reverting them is yours to ask for. Jira calls this `Done` with the
resolution `Won't Do`; GitHub closes the issue as *not planned*.

**Skipping the plan.** The status decides whether there is one, not the kind. Move
`draft` → `planning` to ask for a plan; move `draft` → `planned` yourself, leaving
the task file with no plan in it, and the AI treats that as a waiver and goes
straight to the code. `planned` means cleared to implement either way. To reject a
plan, set `planning` again or `draft` — never delete the plan and leave `planned`,
which reads as a waiver. Review at `in_review` is yours for every kind.

At `in_review` the task file carries a `## How to review` section: a few steps for
seeing the change work, written by whoever implemented it. Start there rather than
with the diff. Nothing records whether you followed it - moving the task to
`approved` is the whole signal.

**What lands on `main`.** With `squash_on_merge` on, a task becomes one commit,
and its message is written to this project's own conventions — the AI reads the
existing history the way it would for any commit. The plugin imposes no format, so
a project that wants a fixed one (Conventional Commits, a ticket prefix, a line
limit) writes it down in its own instructions file — `CLAUDE.md` or whatever this
project uses — not here. What the message
must do is describe the change rather than name the task, because once the branch
is deleted it is the only description left.

Run `/task:clean-tasks` when finished tasks pile up: it deletes each `done` and
each `cancelled` task file with its backlog entry, having first checked — for the
`done` ones — that whatever the task established is written down in the plugin's
skills or here. A cancelled task established nothing, so it is simply deleted. The
plans stay in git history.
