---
id: merge-commit
status: in_review
priority: high
kind: task
branch: task/merge-commit
---

With squash_on_merge, the merge commit is just task: <id>. Merge commit should be
something descriptive of task or change. Is there some best practice on merge
commits that could be used.

changes:
- is merge commit in the scope of task-plugin? Perhaps task-plugin should not state
  merge commit message format at all.
- What kind of merge commits would claude do by default? Should merge commit format
  be in project agents.md file?

# Implementation Plan

The first plan specified a whole message format — subject rules, a body shape, a
bullet list, a trailer, Conventional Commits detection — in a new reference file.
The review asked whether any of that is this plugin's business. It is not. This
plan is the smaller one.

## Is the message format in scope?

Partly, and only the part that is already there. The plugin **does** run the
commit: `approved` → `done` with `squash_on_merge` on executes
`git merge --squash` and then `git commit`, so it cannot avoid deciding what that
commit says. What it can avoid is **prescribing a format**, which is what
`-m "<kind>: <title>"` does today. That template is the whole bug: it is both too
little (it names the ticket, not the change) and too much (it overrides whatever
the project already does).

So the fix is a deletion, not a reference file. Drop the template, say the message
is written like any other commit in that repository, and let the project's own
conventions decide the rest.

## What would Claude do by default?

Without a template, it does what it does for every other commit: read the recent
history for the repository's style, then write a subject that summarises the
change and a body for the why. In this repository that produces
`Add the cancelled status`, not `task: not-done status` — which is the behaviour
the entry asked for, and it arrives by removing an instruction rather than adding
one.

That also answers where a format belongs: **the project's own `CLAUDE.md` or
`AGENTS.md`**, which is where a project states that it uses Conventional Commits,
a ticket prefix, a line limit. The plugin reading it is automatic; the plugin
restating it would only let the two drift. The best practice worth knowing —
imperative subject around 50 characters, blank line, why in the body wrapped at
72 — is git's own convention and the default the agent already follows; writing it
into this plugin would pin a project that deliberately does something else.

The one thing the project cannot know is the task id, so that is the one thing
worth the protocol's breath (open question 1).

## Steps

1. `skills/task/SKILL.md`, **Transitions**, the `approved` → `done` squash case —
   replace

   ```
   git commit -m "<kind>: <title>"
   ```

   with `git commit`, and the sentence that today names the template with: write
   the message as you would any commit in this repository, following its
   conventions; it describes **the change**, not the task's name. State that this
   plugin prescribes no format, and that a project that wants one states it in its
   own `CLAUDE.md` or `AGENTS.md`.
2. `docs/tasks/README.md` — one sentence where the pipeline ends: the squashed
   commit's message is written to the project's own conventions, not to a format
   this plugin imposes, so a project that wants a fixed shape writes it down in
   `CLAUDE.md` or `AGENTS.md`.
3. `README.md` (root) — one clause in the `squash_on_merge` row, or beside it, to
   the same effect, so nobody reads the table and expects a templated message.
4. `.claude-plugin/plugin.json` — bump `version` to `0.8.0`.
5. `tests/Test-Plugin.ps1`:
   * `the approved to done transition states both merge shapes` — add that the
     transition does **not** template a message: no `-m "<kind>`, no
     `<kind>: <title>`.
   * New case: the transition defers the message to the project — it names
     `CLAUDE.md` or `AGENTS.md`, and it says the message describes the change.
     This is the assertion that stops the format creeping back in.
6. Run `tests/Test-Plugin.ps1` and make it green.

No new file, no new configuration key, nothing for a human to configure.

## Decisions

1. **No `Task: <id>` trailer.** The plugin stays entirely out of the message
   beyond "describe the change". `git log --diff-filter=D -- docs/tasks/` finds a
   deleted task file when anyone needs it.
2. **Nothing else about shape.** The project's conventions own it.

## Result

Done as planned, in commit 13ac4bf, across five files. Net effect is a deletion:
the protocol lost a templated subject and gained three sentences saying the
message is the project's to shape.

Two things happened alongside it, both from `create_branch` being turned on
mid-task:

* The work of this task is committed on `main`, not on `task/merge-commit`. The
  flip arrived after the task had started committing, and splitting one task
  across both would read worse than finishing where it began.
* Every task file now names a branch (commit 8c5f0a1). `branch:` names a branch
  without asserting it exists, so backfilling it was enough; the test that
  requires the key for every task file had started failing the moment the
  configuration changed.

## How to review

1. Run the suite — `powershell -NoProfile -File tests\Test-Plugin.ps1`. It prints
   `passed 65, failed 0, skipped 0`. 64 passed before; the new case is `the
   squashed commit message is the project-s, not the plugin-s`. Run; that is the
   output.
2. `git show 13ac4bf -- skills/task/SKILL.md` — the whole change. The command
   block lost `-m "<kind>: <title>"`, and the paragraph under it is what replaced
   it. Check it tells you nothing about subject length, mood or prefixes.
3. The same commit's test diff has two guards: the transition may not contain
   `git commit -m`, `-m "<kind>` or `<kind>: <title>`, and it must point a project
   at its own instructions file. The first is what stops the template growing
   back.
4. `git show 13ac4bf -- docs/tasks/README.md README.md` for the two human-facing
   paragraphs. `docs/tasks/README.md` says "`CLAUDE.md` or whatever this project
   uses" rather than naming `AGENTS.md`: the test `no living file names AGENTS.md
   as the rules` forbids that file naming it, and the root README, which is
   outside that guard, names both.
5. **Not run:** the squash itself, so no message was written by these rules. This
   project's own history is the nearest evidence of what the agent writes without
   a template — `git log --oneline -8` shows the subjects, including this task's.
