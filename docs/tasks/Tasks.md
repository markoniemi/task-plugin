---
create_branch: false
create_pull_request: false
---

# Task Backlog

Inbox for new tasks. A human adds an entry; the AI turns it into a task file. See
`README.md` for how. The rules come from the `task` plugin, not from this
directory.

Entry format — `### [<kind>: ]<short title> [<status>, <priority>]` plus a short
explanation. Once the AI has created the task file, it adds a `file: <link>` line
under the heading and keeps the brackets up to date as the status changes. An entry
is removed when its task is cleaned, so this file shows open work only.

Kinds are `feature:`, `bug:` and `task:`, written before the title, and they decide
what the branch is called and nothing else. No prefix means `task`.

Statuses:

* `draft` — written down, not planned yet.
* `planning` — a human asked the AI to plan it.
* `planned` — cleared to implement: a plan written and waiting for a human to
  verify it, or set by a human **with no plan** in the task file, which waives it.
* `in_progress` — the AI is implementing it on its branch.
* `in_review` — implementation ready on the branch, waiting for review.
* `changes_requested` — review asked for changes.
* `approved` — review passed, ready to merge.
* `done` — merged and branch deleted.
* `cancelled` — it will not happen, or it happened and was reverted. A human sets
  it, from any status but `done`, and nothing comes back out of it.

Priorities: `high` | `medium` | `low`.

---

## Backlog


### powerpoint presentation [draft, low]

- when tasks workflow and plugin/skill implementation, a powerpoint presentation would be nice

### not-done status [in_review, high]

file: [not-done-status.md](not-done-status.md)

Need a status stating that task is not implemented or the implementation reverted. What is the corresponding state in jira? Status means that task file can deleted, branch and commits removed and no need to update docs when task is deleted.
 
### squash commit [done, high]

file: [squash-commit.md](squash-commit.md)

Add config item that tells ai to squash commits when merging to main.

### remind to clear context [planning, low]

Is it possible to remind user to clear context after task is merged to master (or set to done)?

### merge commit [planned, high]

file: [merge-commit.md](merge-commit.md)

With squash_on_merge, the merge commit is just task: <id>. Merge commit should be something descriptive of task or change. Is there some best practice on merge commits that could be used.

changes:
- is merge commit in the scope of task-plugin? Perhaps task-plugin should not state merge commit message format at all. 
- What kind of merge commits would claude do by default? Should merge commit format be in project agents.md file?

