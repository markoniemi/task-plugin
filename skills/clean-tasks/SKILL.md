---
name: clean-tasks
description: Use only when a human asks to clean up or prune finished tasks - "clean tasks", "delete the done tasks", "tidy docs/tasks". Deletes each done task file and its backlog entry, after checking that whatever the task established is written down somewhere that survives.
---

# Clean tasks

Read the protocol first: `${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md`.

**Never on your own, and never as part of reaching `done` or `cancelled`.** Clean
only when a human asks for it. Reaching either leaves the task file in place on
purpose: it is the record until someone decides the record is spent.

Delete every `done` and every `cancelled` task, oldest first, **one commit per
task**:

1. **`done` only.** Check that every rule, decision or constraint the task
   established is already written down where it survives the deletion: this
   plugin's skills if it changed the protocol, or the project's own `README.md` or
   instructions file if it changed the project. Write it there first if it is not.
   What only described how the work was carried out is not worth keeping.

   A `cancelled` task established nothing — that is what cancelling it said — so
   skip this step for one and go straight to the deletion.

   Keeping the documentation correct is **not this skill's** job. The task that
   changed the behaviour updated it while implementing it, as the protocol's
   `planned` -> `in_progress` requires. This step only checks that a rule is not
   lost together with the file that holds it.
2. Delete the task file.
3. Remove its whole entry from `Tasks.md`, heading and `file:` line included.

Nothing of a `done` task stays in the task directory except what it changed, and
nothing of a `cancelled` one stays at all. The plans stay in git history:
`git log --diff-filter=D -- docs/tasks/` finds them.

Report what you deleted and what you had to write down first.
