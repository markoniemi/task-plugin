---
name: task
description: Use when asked to start, continue or finish a named task from the backlog, or when you need the task protocol itself - the status names, the task file shape, the backlog mirror and the transitions. Invoked as /task:task [name-of-task]. The task name is whatever the backlog entry's heading says.
argument-hint: "[name-of-task]"
---

# Task Protocol

The rules for processing tasks in a project's task directory, normally
`docs/tasks/`. This file is the single source of truth for the rules. A project's
own `README.md` explains them to humans; it does not restate them.

ARGUMENTS: `$ARGUMENTS` is the name of the task to work on — the heading of a
`Tasks.md` entry, or the name of a task file. With no arguments, state the protocol
and list the tasks with their statuses, and ask which one to take.

## Starting from the task name

1. Find the task. Match `$ARGUMENTS` against the headings in `Tasks.md` — both
   whole and with the kind prefix stripped (see **Kinds**) — and against the task
   file names, case-insensitively; a partial match is enough when it is
   unambiguous. Two candidates → ask which one.
2. No task file yet → create it as **Creating a task** below describes, then
   continue.
3. A task file exists → read its frontmatter, reconcile it with the entry's brackets
   (see **Backlog mirror**), and run the transition its `status` calls for in
   **Transitions**. Stop at the first step that is a human's.

## Task files

* A task is a file `docs/tasks/<slug>.md`, where `<slug>` is the slug of its
  backlog heading, derived as **Creating a task** below describes. The task files
  are every `*.md` in `docs/tasks/` except `README.md` and `Tasks.md`.
* Every task file starts with this frontmatter:

```yaml
---
id: short-description
status: draft | planning | planned | in_progress | in_review | changes_requested | approved | done | cancelled
priority: high | medium | low
kind: feature | bug | task
branch: task/short-description
---
```

* `kind:` is the kind the heading's prefix names (see **Kinds**). No `kind:` key
  means `task`, so a task file written before kinds existed still reads correctly.
* `branch:` is there when `create_branch` permits a branch (see
  **Configuration**), and it always reads `<kind>/<id>`. The key **names** the
  branch; it does not assert that the branch exists yet (see **Lazy branches**).
  With `create_branch` off the task has no branch and the key is left out.
* The task file is the source of truth for `status` and `priority`. The brackets in
  `Tasks.md` mirror it; keep them in step (see **Backlog mirror**).


## Kinds

A backlog heading may say what kind of work it is, before a colon:

```markdown
### feature: add a login page [draft, high]
### bug: duplicate invoice rows [draft, high]
### task: bump the plugin version [draft, low]
### bump the plugin version [draft, low]
```

The last two mean the same thing: **no prefix means `task`**.

| Kind | Branch |
| :- | :- |
| `feature` | `feature/<slug>` |
| `bug` | `bug/<slug>` |
| `task` | `task/<slug>` |

Naming the branch is all a kind decides. Whether a plan is required is the
**status** (see **Transitions**); whether a branch is permitted at all is
**Configuration**.

* The prefix is matched case-insensitively, and `feature`, `bug` and `task` are
  the only three kinds. `hotfix` is not one: it names urgency, and nothing in this
  protocol acts on urgency.
* **The prefix is stripped before the slug is derived**, so the first example gives
  the slug `add-a-login-page` and the branch `feature/add-a-login-page`, not
  `feature/feature-add-a-login-page`.
* A word before a colon that is not one of the three is part of the title:
  `### fix: parser crash` is a `task` titled `fix: parser crash`. A colon in a
  title is ordinary English — do not guess at a fourth kind, and do not stop to
  ask.
* The brackets stay `[<status>, <priority>]`. The kind never goes in them.
* Every kind is reviewed by a human. **No kind skips `in_review`**, and every kind
  writes `## How to review` on the way there.

## Creating a task

When the named task has no task file yet:

1. Read the kind and the title from the heading as **Kinds** describes, then derive
   the slug from the title: lower-case it, replace every run of characters outside
   `a-z0-9` with a single `-`, then strip any leading and trailing `-`. So
   `task id/name` gives `task-id-name`.
2. Check the slug. It must match `^[a-z0-9][a-z0-9-]*[a-z0-9]$`, be at most 60
   characters long, and belong to no existing task file. A slug that matches that
   pattern is always a legal git branch name, so nothing else has to be checked.
   When the check fails, do not invent a different slug: stop and ask the human to
   edit the heading.
3. Write `docs/tasks/<slug>.md` with `id: <slug>` and `kind: <kind>`, and
   `branch: <kind>/<slug>` when `create_branch` is on (see **Configuration**);
   leave `branch:` out when it is off. Take `status` and `priority` from the
   entry's brackets.
4. Copy the entry's explanation into the body as the task description. Do not write
   an implementation plan yet.
5. Add a link to the task file as the first line under the entry's heading:
   `file: [<slug>.md](<slug>.md)`. Leave the heading and its brackets as they are.

For *the next task* rather than a named one, use the `next-task` skill.

## Backlog mirror

The brackets in a `Tasks.md` entry always read `[<status>, <priority>]`, for the
whole life of the task. Keep the mirror in step, in both directions:

* You change a task file's `status` → update that entry's brackets in the same
  commit.
* A human changed the brackets → copy the new `status` and `priority` into the task
  file's frontmatter when you next pick the task up, and work from that.
* The heading's prefix and the task file's `kind:` say the same thing. A human who
  changed the prefix changed the kind: copy it across, and update `branch:` with
  it. Once the branch exists its name is fixed, so report the mismatch and stop
  rather than renaming a branch or leaving the two out of step.

## Configuration

Three keys decide what the transitions may do. All three are booleans.

| Key | Default | What it decides |
| :- | :- | :- |
| `create_branch` | `true` | A task may have its own branch. |
| `create_pull_request` | `false` | Reaching `in_review` opens a request on the host. |
| `squash_on_merge` | `true` | Merging a task branch squashes it into one commit. |

Precedence for each key, highest first:

1. The YAML frontmatter at the very top of `docs/tasks/Tasks.md`:

   ```markdown
   ---
   create_branch: true
   create_pull_request: false
   squash_on_merge: true
   ---
   ```

2. The value the human gave Claude Code for this plugin: `create_branch` is
   `${user_config.create_branch}`, `create_pull_request` is
   `${user_config.create_pull_request}` and `squash_on_merge` is
   `${user_config.squash_on_merge}`.
3. The defaults in the table above.

An unknown key in that frontmatter is ignored. A value that is neither `true` nor
`false` is not guessed at: stop and ask the human to fix it. A frontmatter block
that is not at the very top of `Tasks.md` is not configuration.

The first two keys are a **ceiling, not a default**: `false` takes the thing away
from every task and nothing per task overrides it, and `true` only permits it —
which work uses one is this protocol's decision.

`squash_on_merge` is not a ceiling. It shapes **the one merge this protocol
performs itself**, in `approved` → `done` with a branch and no request, and it
decides nothing anywhere else: with no branch nothing is merged, and with a
request the host merges and squashes by its own settings.

`create_pull_request: true` together with `create_branch: false` is a
contradiction: there is no branch to open a request from. Report it and stop
rather than resolving it either way.

## Lazy branches

With `create_branch` on, the branch is not made when a task reaches
`in_progress`. It is made at the first moment there is **something to commit**:
create the branch named in `branch:`, switch to it, and commit there.

A task that turns out to write no code — a decision record — therefore never
creates a branch at all, and reaching `done` has nothing to merge. That is why
`branch:` names a branch and **does not assert** that the branch exists.

## Transitions

**`draft` → `planning` or `planned`** — human only, both routes, and the human
chooses which. Do not set either yourself.

* `planning` asks for a plan.
* `planned` with no `# Implementation Plan` section means there is nothing worth
  planning: implement it.

**`planning` → `planned`** — append a `# Implementation Plan` section to the task
file: the steps, and any open question a human must answer. Set `planned` and stop;
a human verifies the plan.

**`planned` → `in_progress`** — set `in_progress` and commit it on `main`. A
`# Implementation Plan` section in the task file is one a human verified; its
absence means the human waived the plan. Either way, implement it — never go back
and write a plan for a task a human set to `planned` without one.

Write the code, the **unit tests** and the documentation the change makes wrong.
With `create_branch` on, that work goes on the task's branch, made when there is
something to commit (see **Lazy branches**). With `create_branch` off, leave
`branch:` out of the task file's frontmatter and commit everything on `main`. No
later step audits the documentation.

A human who rejects a plan sets `planning` again, or `draft` — never `planned`
with the plan section deleted, which this transition reads as a waiver.

**`in_progress` → `in_review`** — the implementation is committed and ready to be
read. With `create_pull_request` off, nothing is pushed and nothing is opened: set
`in_review`, and the human reads the branch, or the commits on `main` when there
is no branch. With `create_pull_request` on, push the branch, open the request as
`${CLAUDE_PLUGIN_ROOT}/skills/task/references/host.md` describes — read that file
now — add its URL to the task file as a `pr:` line under the frontmatter, and set
`in_review`.

Either way, append a `## How to review` section to the task file first - a handful
of steps in whichever of these shapes fits the change: how to reach the screen and
what to look at, the exact command and the output to expect, or what to read in
what order and the command that proves it. Write steps you have run; a step you
have not run, a click-through you could not perform, says so. Do not restate the
plan or the `## Result`.

**`in_review` → `approved`** — human only. A human follows `## How to review` and
reads the branch diff, the commits on `main` when there is no branch, or the open
request on the host. Nothing tracks whether they did: the status reaching
`approved` is the whole signal. Accepted → `approved`. Otherwise →
`changes_requested`.

**`changes_requested` → `in_review`** — fix what the review asked for where the work
lives, the task branch or `main`, commit, and set `in_review`. An open request
picks the new commits up when the branch is pushed.

**`approved` → `done`** — how the work lands depends on what was permitted:

* No branch, or a branch `branch:` names that was never made: there is nothing to
  merge, so `squash_on_merge` decides nothing. Set `done` and mirror it.
* A branch and no request: merge it into `main`, delete the branch, set `done`.
  How you merge is `squash_on_merge`:
  * On — the default — squash the branch into one commit whose message is
    `<kind>: <title>` from the backlog heading:

    ```
    git merge --squash <branch>
    git commit -m "<kind>: <title>"
    git branch -D <branch>
    ```

    The delete is `-D` here because git does not record a squashed branch as
    merged and `-d` refuses it. Nothing else justifies `-D`.
  * Off: merge it fast-forward and delete the branch with `git branch -d`.
* A request: the host merges it, not you, and the host squashes and deletes the
  branch by its own settings, so `squash_on_merge` decides nothing here either.
  Check that it is merged as
  `${CLAUDE_PLUGIN_ROOT}/skills/task/references/host.md` describes — read that
  file now. Merged: delete the local branch and set `done`. Not merged yet: say so
  and stop, because merging it is the human's.

**any → `cancelled`** — human only, from every status but `done`, and terminal:
the work will not happen, or it happened and was reverted. Never set it yourself,
whatever the task turns out to cost. A human who changes their mind sets the
status back by hand; nothing transitions out of `cancelled`.

What you do when you next pick a `cancelled` task up:

* A branch the task made, never merged: delete it with `git branch -D <branch>`.
  Its commits stay reachable through the reflog until the repository's `gc`
  collects them, which is the only undo this needs.
* Commits already on `main` — the task was reverted, or the project has no
  branches: **name them and stop.** Never revert, reset or force-push to undo a
  cancelled task. Reverting published work is the human's call, and they ask for
  `git revert` by name.
* Nothing committed: nothing to do.

A cancelled task established nothing, so no documentation follows it.

## Cleaning up

Deleting finished tasks is the `clean-tasks` skill, and it happens only when a human
asks for it — never as part of reaching `done`, and never as part of cancelling.

## Shell

On Windows, use the PowerShell tool rather than Bash.

* No `&&` or `||` in PowerShell 5.1: use `;`, and `if ($?) { ... }` to run a command
  only when the previous one succeeded.
* `python` may not be on `PATH`.
* Here-strings (`@'...'@`), not heredocs. The closing `'@` must start at column 0.
