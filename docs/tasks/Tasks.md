---
create_branch: true
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

### not-done status [done, high]

file: [not-done-status.md](not-done-status.md)

Need a status stating that task is not implemented or the implementation reverted. What is the corresponding state in jira? Status means that task file can deleted, branch and commits removed and no need to update docs when task is deleted.
 
### audit context [planned, high]

file: [audit-context.md](audit-context.md)

1. run audit context and write results to a file,
2. create a plan to fix findings,
3. review plan
4. fix findings

### reduce skill files [planning, low]

- skill files are long, is there something that can be removed?
- 
