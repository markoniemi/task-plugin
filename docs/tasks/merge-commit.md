---
id: merge-commit
status: planned
priority: high
kind: task
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

## Open questions

1. **A `Task: <id>` trailer.** The only task-specific thing a project's
   conventions cannot supply: a git trailer on the squashed commit, so a commit on
   `main` still points at the task file after `clean-tasks` deletes it. Three
   answers: require it, suggest it, or leave it out and keep the plugin entirely
   out of the message. The plan assumes **leave it out** — it is the position the
   review's first question implies, and `git log --diff-filter=D -- docs/tasks/`
   already finds a deleted task file.
2. **Nothing else.** If you want the plugin to keep saying *anything* about shape
   beyond "describe the change", say which sentence and it goes in step 1.
