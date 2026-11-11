---
name: init
description: Use when a project has no task backlog yet and someone asks to set tasks up - "init tasks", "set up the backlog", "create Tasks.md", /task:init. Creates docs/tasks/Tasks.md and docs/tasks/README.md from this plugin's templates, and changes nothing when they already exist.
---

# Init

Set `docs/tasks/` up in a project that does not have it yet. The protocol itself,
for what these files mean, is
`${CLAUDE_PLUGIN_ROOT}/skills/task/SKILL.md`.

## What to do

1. `docs/tasks/Tasks.md` exists already: **change nothing.** Report what is there
   - the entries and their statuses, and the task files beside it. If its first
   line is not `---`, say that the configuration frontmatter is missing and show
   the block that belongs at the top, but do not add it: that is the human's call,
   because it decides whether the project uses branches.
2. Otherwise create the directory and copy both templates verbatim:
   * `${CLAUDE_PLUGIN_ROOT}/skills/init/templates/Tasks.md` to
     `docs/tasks/Tasks.md`
   * `${CLAUDE_PLUGIN_ROOT}/skills/init/templates/README.md` to
     `docs/tasks/README.md`

   Copy them as they stand. Do not rewrite, summarise or reflow them, and do not
   fill the empty `## Backlog` heading with an example.
3. Commit the two files.
4. Report the two paths, the configuration the frontmatter now states
   (`create_branch: true`, `create_pull_request: false`, `squash_on_merge: true`)
   and that it is edited in
   `Tasks.md`, and that the next step is a backlog entry plus
   `/task:task <heading>`.

## What this skill never does

* It writes no task file. Creating one is the `task` skill's business, from a
  backlog entry a human wrote.
* It touches no `README.md` outside `docs/tasks/`.
* It asks no questions. The templates carry the defaults; a project that needs
  something else edits the frontmatter afterwards.