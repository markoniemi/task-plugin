---
id: merge-commit
status: planned
priority: high
kind: task
---

With squash_on_merge, the merge commit is just task: <id>. Merge commit should be
something descriptive of task or change. Is there some best practice on merge
commits that could be used.

# Implementation Plan

## The complaint is right

`squash-commit` specified the message as `<kind>: <title>` from the backlog
heading, so a task lands as `task: squash commit`. That names the ticket, not the
change. It is also the one commit anyone reading `main` later will see: the
individual commits are gone, so whatever is not in that message is lost to
`git log` and recoverable only through the reflog.

It does not even match this repository's own history, which is imperative and
descriptive — `Add the cancelled status`, `Let a project omit a configuration key
the template states` — with `<id>: <status>` reserved for the task-file commits.

## What the best practice actually is

Three conventions are worth taking from, and they do not conflict:

1. **Git's own** (`Documentation/SubmittingPatches`, and Tim Pope's note that
   everyone cites): a short subject in the imperative mood, capitalised, no
   trailing full stop, around 50 characters; a blank line; then a body wrapped at
   72 that says **why**, not how. The diff already says how.
2. **Conventional Commits 1.0.0**: `<type>(<scope>): <description>`, where the
   type is `feat`, `fix`, `chore` and so on. Worth following *only in a project
   that already follows it*, because its value is machine-readable history —
   changelog generation, semantic-version bumps — and a project that has it
   half-applied gets neither.
3. **What a squash lands**: GitHub's default squash message is the pull request
   title plus a bullet per squashed commit. The bullets are the part worth
   keeping: they are the only remaining trace of how the work was built up.

A merge commit for a merged series — a kernel-style pull — describes the series
as a whole. A squash is that, with the series collapsed, so the same rule holds:
the message describes the change, and lists what went into it.

## The shape this plugin should write

```
<Imperative subject describing the change, ~50 chars, no full stop>

<Why the change was made, wrapped at 72. One or two paragraphs. The task
file's own description and its ## Result are the material.>

* <subject of the first squashed commit>
* <subject of the second>

Task: <id>
```

Rules the protocol will state:

* The subject describes **the change**, never the ticket. `Add the cancelled
  status`, not `task: not-done status`. The backlog heading is a fallback when
  the agent has nothing better, not the source.
* No `<kind>:` prefix. The kind names the branch; it says nothing a reader of
  `main` needs.
* **Match the repository, not this file.** Before writing the message, read
  `git log --oneline -20 --no-merges`. If most subjects match
  `^(feat|fix|chore|docs|refactor|test|build|ci|perf)(\(.+\))?!?: `, the project
  uses Conventional Commits, so write one, mapping `feature` → `feat`, `bug` →
  `fix`, `task` → `chore`. Otherwise write the plain imperative subject. No
  configuration key: the repository's own history already answers this, and a key
  would let it drift from the answer.
* The bullet list is dropped when the task squashed a single commit, where it
  would only repeat the subject.
* `Task: <id>` as the last line, a git trailer, so the task file that holds the
  plan and the review steps is findable from `main` after `clean-tasks` has
  deleted it.

This lands in a reference file rather than in the protocol: it is needed at one
moment, `approved` → `done` with `squash_on_merge` on, and the protocol is read
on every invocation. That is exactly the split `references/host.md` already uses.

## Steps

1. New `skills/task/references/commit-message.md` — the shape above, the four
   rules, the Conventional Commits detection command and mapping, and two worked
   examples (one plain, one conventional). Short: it is read at one moment.
2. `skills/task/SKILL.md`, **Transitions**, the `approved` → `done` squash case —
   replace `git commit -m "<kind>: <title>"` with `git commit` and a line saying
   to write the message as `${CLAUDE_PLUGIN_ROOT}/skills/task/references/commit-message.md`
   describes, read now. Keep the commands otherwise as they are.
3. `docs/tasks/README.md` — one sentence under the pipeline: what the squashed
   commit on `main` looks like, and that the `Task: <id>` trailer is how you get
   back from a commit to the task that explains it.
4. `README.md` (root) — one clause where `squash_on_merge` is described, so a
   reader of the table knows the message is written, not templated.
5. `.claude-plugin/plugin.json` — bump `version` to `0.8.0`. No new key.
6. `tests/Test-Plugin.ps1`:
   * `the approved to done transition states both merge shapes` — it currently
     asserts the transition names `git merge --squash`; add that it names
     `references/commit-message.md`, and that it no longer templates
     `-m "<kind>: <title>"`.
   * New case: the reference file exists and states the subject rule, the
     imperative mood, the `Task:` trailer, and the Conventional Commits
     detection — mirroring `the request path names both hosts and their commands`,
     which guards `host.md` the same way.
7. Run `tests/Test-Plugin.ps1` and make it green.

## Open questions

1. **Conventional Commits** — the plan detects the repository's style from
   `git log` and follows it, with no configuration key. The alternatives are
   always Conventional Commits, or never. Detection is the recommendation: this
   repository would get its plain imperative subjects, and a project with
   `feat:`/`fix:` history would get its own convention without being asked.
2. **The bullet list of squashed commits** — kept (dropped for a single commit).
   The alternative is prose only, which reads better but loses the only trace of
   how the work was built up.
3. **The `Task: <id>` trailer** — kept. Say if you would rather the commit stayed
   free of task-tracking metadata, in which case nothing on `main` points back at
   the task file once it is cleaned.
