---
id: not-done-status
status: in_progress
priority: high
kind: task
---

Need a status stating that task is not implemented or the implementation reverted.
What is the corresponding state in jira? Status means that task file can deleted,
branch and commits removed and no need to update docs when task is deleted.

# Implementation Plan

## What Jira calls it

Jira has no status for this. It has a **resolution**: the issue moves to `Done`
and carries the resolution `Won't Do` (older workflows: `Won't Fix`). The status
says where the issue is in the workflow; the resolution says how it left. So in
Jira terms, "not implemented" is `Done` + `Won't Do`, not a status of its own.
GitHub says the same thing differently: an issue is closed **as not planned**.

This protocol has no resolution field, and adding one to carry a single value
would cost more than it pays. So the plan adds a status, and makes it terminal
beside `done` rather than a replacement for it:

* `done` — it happened.
* `cancelled` — it did not, and nobody is waiting for it.

## What the status means

`cancelled` is **terminal and human-only**, reachable from every status except
`done`. The agent never sets it; deciding that work will not happen is not its
call. It covers three cases, which the protocol states so the agent does not have
to guess:

1. Never implemented — the task was dropped at `draft`, `planning` or `planned`.
2. Implemented, then judged wrong at `in_review` — the human sets `cancelled`
   instead of `changes_requested`.
3. Implemented, landed, and then reverted.

What the agent does on entering `cancelled`:

* **An unmerged branch exists** → delete it: `git branch -D <branch>`. The
  commits stay reachable through the reflog for the repository's `gc` window,
  which is the only undo anyone needs here.
* **Work already landed on `main`** (case 3, or `create_branch: false`) → the
  agent does **not** revert and does **not** rewrite history. It says which
  commits the task made and stops; reverting published commits is the human's
  decision, and `git revert` is theirs to ask for by name.
* **Nothing was committed** → nothing to do.

What it means for cleaning: `clean-tasks` today checks, before deleting a `done`
task file, that whatever the task established is written down where it survives.
A `cancelled` task established nothing, so that check is skipped — the file and
its backlog entry are deleted outright. The plan is already in git history either
way.

## Steps

1. `skills/task/SKILL.md`:
   * **Task files** — add `cancelled` to the `status:` line of the frontmatter
     block.
   * **Transitions** — add a `**any → `cancelled`**` entry after `approved` →
     `done`: human only, what the agent does with a branch, and the refusal to
     touch commits already on `main`.
   * State that `cancelled` is terminal: nothing transitions out of it, and a
     human who changes their mind sets the status back by hand.
2. `skills/clean-tasks/SKILL.md` — it deletes every `done` task; make that "every
   `done` or `cancelled` task", and say that step 1's check applies only to
   `done`, because a cancelled task established nothing.
3. `skills/init/templates/Tasks.md` — add `cancelled` to the status list, one
   line, and to the pipeline wording if the template carries one.
4. `docs/tasks/Tasks.md` — same status-list line, since this project's backlog
   states the statuses too.
5. `docs/tasks/README.md` — add it to the pipeline diagram as a terminal state
   beside `done`, and one sentence on what the human is signing up for (branch
   deleted, nothing on `main` touched).
6. `README.md` (root) — one line in the status list, and the Jira/GitHub
   equivalence as a parenthesis, since that is what makes the name legible to
   someone arriving from either tool.
7. `.claude-plugin/plugin.json` — bump `version` to `0.7.0`. No new config key:
   this is a status, not a choice.
8. `tests/Test-Plugin.ps1`:
   * `every status name survives in the task skill` — add `cancelled`.
   * `the backlog template is a valid backlog` and `the template and this project
     do not drift` — add `cancelled` to both status lists.
   * New case: the `cancelled` transition is human-only, names `git branch -D`,
     and does **not** name `git revert`, `reset --hard` or `push --force`.
   * New case: `clean-tasks` names `cancelled` and still guards the `done` check.
9. Run `tests/Test-Plugin.ps1` and make it green.

## Decisions

1. **The name** — `cancelled`.
2. **Reverting** — no revert on cancel. The agent names the commits the task made
   and stops; reverting published work is the human's to ask for by name.
3. **`clean-tasks` scope** — `clean-tasks` deletes cancelled tasks, alongside the
   done ones, when a human asks it to clean. Cancelling does not delete anything
   by itself.
