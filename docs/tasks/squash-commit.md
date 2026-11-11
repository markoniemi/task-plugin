---
id: squash-commit
status: planned
priority: high
kind: task
---

Add config item that tells ai to squash commits when merging to main.

# Implementation Plan

## What the key does

A third configuration key, `squash_commits`, default `false`, alongside
`create_branch` and `create_pull_request`. It is read from the same three layers,
with the same precedence, and it is the same kind of ceiling: `false` means no
task is ever squashed.

It bites in exactly one place: the **`approved` → `done`** transition, on the
branch-and-no-request path, which today reads "merge it into `main`
(fast-forward), delete the branch". With `squash_commits` on that path becomes:

```
git merge --squash <branch>
git commit -m "<kind>: <title>"
git branch -D <branch>
```

`git branch -d` refuses a squash-merged branch — git does not see it as merged —
so the delete must be `-D` on that path only. The fast-forward path keeps `-d`.

The other two `approved` → `done` paths are unaffected, and the plan states why
in the protocol so the agent does not improvise:

* **No branch** (`create_branch: false`, as in this project): there is nothing to
  merge, so there is nothing to squash. The key never rewrites commits already on
  `main`.
* **A request**: the host merges, not the agent. The agent never runs a merge
  there, so the key cannot change what it does. `references/host.md` gains one
  line saying the human chooses the squash option in the host's UI (`gh pr merge
  --squash`, `glab mr merge --squash`) when the project sets `squash_commits`.

## Steps

1. `.claude-plugin/plugin.json` — add `squash_commits` to `userConfig`
   (`"type": "boolean"`, title, description, `"default": false`), and bump
   `version` to `0.6.0`.
2. `skills/task/SKILL.md`:
   * **Configuration** — "Two keys" becomes "Three keys"; add the table row; add
     the frontmatter example line; add `${user_config.squash_commits}` to the
     precedence list.
   * **Transitions**, `approved` → `done` — split the branch-and-no-request
     bullet into the fast-forward case and the squash case with the three
     commands above and the `-D` note; add the one-line no-op statement to the
     no-branch and the request bullets.
3. `skills/task/references/host.md` — one line: with `squash_commits` on, the
   human merges the request with the host's squash option.
4. `skills/init/templates/Tasks.md` — add `squash_commits: false` to the
   frontmatter and one clause to the sentence that explains the other two keys.
5. `skills/init/SKILL.md:29` — add the key to the defaults it lists.
6. `docs/tasks/README.md` — add the table row under **Configuration**, and the
   sentence that `squash_commits` needs `create_branch: true` to mean anything.
7. `README.md` (root) — same table row and the same sentence.
8. `docs/tasks/Tasks.md` — add `squash_commits: false` to this project's own
   frontmatter, so the template-drift test keeps passing.
9. `tests/Test-Plugin.ps1`:
   * `$script:ConfigDefaults` (line 174) — add `squash_commits = $false`.
   * 'the manifest declares both configuration options' (line 335) — add the
     `@('squash_commits', $false)` pair; rename to "all three".
   * 'the protocol states the keys, the layers and the precedence' (line 361) —
     add `squash_commits` to the rule list.
   * 'configuration is read from the frontmatter over the defaults' (line 420) —
     add a `Squash` column to every case, a `squash on` case, and the assertion.
   * 'this project states its own configuration' (line 448) and 'the template and
     this project do not drift' (line 494) — add the key to both lists.
   * 'the backlog template is a valid backlog' (line 472) — assert the template
     default is `$false`.
   * New case: the `approved` → `done` transition names `merge --squash` and
     `branch -D`.
10. Run `tests/Test-Plugin.ps1` and make it green.

## Open questions

1. **Key name** — `squash_commits`, or `squash_on_merge` which says when it
   applies? The plan assumes `squash_commits`.
2. **Default** — `false` keeps every existing project behaving as it does today.
   Confirm, or make it `true`.
3. **The squash commit message** — the plan assumes `<kind>: <title>` from the
   backlog heading, one line, no body. The alternative is a body listing the
   squashed subjects.
4. **The request path** — the plan leaves it to the human and only documents it
   (step 3). The alternative is the agent running `gh pr merge --squash` itself,
   which would be the first time it merges a request; that conflicts with "the
   host merges it, not you".
