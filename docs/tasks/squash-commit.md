---
id: squash-commit
status: in_review
priority: high
kind: task
---

Add config item that tells ai to squash commits when merging to main.

# Implementation Plan

## What the key does

A third configuration key, `squash_on_merge`, default `true`, alongside
`create_branch` and `create_pull_request`. It is read from the same three layers,
with the same precedence.

**It governs the one merge the agent performs itself, and nothing else.** The
plugin owns a merge only on the branch-and-no-request path of **`approved` →
`done`**; with a request the host merges, squashes and deletes, and with no
branch there is no merge at all. The key is therefore a no-op in both of those,
and the protocol says so in one line each so the agent does not improvise.

That path today reads "merge it into `main` (fast-forward), delete the branch".
With `squash_on_merge` on — the default — it becomes:

```
git merge --squash <branch>
git commit -m "<kind>: <title>"
git branch -D <branch>
```

`git branch -d` refuses a squash-merged branch — git does not see it as merged —
so the delete must be `-D` on that path only. With the key off, the merge stays
fast-forward and the delete stays `-d`.

The other two `approved` → `done` paths:

* **No branch** (`create_branch: false`, as in this project): nothing is merged,
  so nothing is squashed. The key never rewrites commits already on `main`.
* **A request**: the host merges, squashes and deletes the branch, by its own
  repository settings. The agent runs no merge there, so the key cannot change
  anything. `references/host.md` is left alone: the host's squash option is that
  host's configuration, not this plugin's.

## Steps

1. `.claude-plugin/plugin.json` — add `squash_on_merge` to `userConfig`
   (`"type": "boolean"`, title, description, `"default": true`), and bump
   `version` to `0.6.0`.
2. `skills/task/SKILL.md`:
   * **Configuration** — "Two keys" becomes "Three keys"; add the table row; add
     the frontmatter example line; add `${user_config.squash_on_merge}` to the
     precedence list. State there that this key, unlike the other two, governs
     only the merge the agent performs itself.
   * **Transitions**, `approved` → `done` — split the branch-and-no-request
     bullet into the squash case (default) and the fast-forward case, with the
     three commands and the `-D` note; add the one-line no-op statement to the
     no-branch and the request bullets.
3. `skills/init/templates/Tasks.md` — add `squash_on_merge: true` to the
   frontmatter and one clause to the sentence that explains the other two keys.
4. `skills/init/SKILL.md:29` — add the key to the defaults it lists.
5. `docs/tasks/README.md` — add the table row under **Configuration**, and the
   sentence that the key means nothing without `create_branch: true` and nothing
   with `create_pull_request: true`, because the host squashes there.
6. `README.md` (root) — same table row and the same sentence.
7. `docs/tasks/Tasks.md` — add `squash_on_merge: true` to this project's own
   frontmatter, so the template-drift test keeps passing. It is a no-op here
   (`create_branch: false`), and that is the point of writing it down.
8. `tests/Test-Plugin.ps1`:
   * `$script:ConfigDefaults` (line 174) — add `squash_on_merge = $true`.
   * 'the manifest declares both configuration options' (line 335) — add the
     `@('squash_on_merge', $true)` pair; rename to "all three".
   * 'the protocol states the keys, the layers and the precedence' (line 361) —
     add `squash_on_merge` to the rule list.
   * 'configuration is read from the frontmatter over the defaults' (line 420) —
     add a `Squash` column to every case, a `squash off` case, and the assertion.
   * 'this project states its own configuration' (line 448) and 'the template and
     this project do not drift' (line 494) — add the key to both lists.
   * 'the backlog template is a valid backlog' (line 472) — assert the template
     default is `$true`.
   * 'the branch path survives the rewrite' (line 373) — it asserts
     `fast-forward` is still stated; keep that wording in the off case so the
     assertion holds.
   * New case: the `approved` → `done` transition names `merge --squash` and
     `branch -D`, and the request bullet still says the host merges.
9. Run `tests/Test-Plugin.ps1` and make it green.

## Decisions

1. **Key name** — `squash_on_merge`. It says when it applies.
2. **Default** — `true`. Existing projects that merge a local branch start
   getting one commit per task; projects with requests or without branches are
   unaffected.
3. **The squash commit message** — `<kind>: <title>` from the backlog heading,
   one line, no body.
4. **The request path** — the key is a no-op. The host merges, squashes and
   deletes by its own settings, and the agent never runs `gh pr merge`.
   `references/host.md` is not touched.
5. **`commit_after_review` was considered instead and rejected.** It would have
   the agent hold the implementation uncommitted until a human sets `approved`.
   That removes git as the safety net over the longest wait in the pipeline, it
   leaves nothing for `create_pull_request` to open a request from, it gives the
   reviewer a working tree instead of a diff, and it loses the record of what
   changed between review rounds. It collides with the protocol besides: both
   `in_progress` and `in_review` commit the task file.
6. **Scope** — the plugin squashes only what the plugin merges. Making the key
   bite in this repository means `create_branch: true` here, which is its own
   backlog entry, not part of this task.

## Result

Done as planned, in commit 784137d, across eight files. The one deviation: step 8
grew an extra assertion — `the branch path survives the rewrite` still demands the
word `fast-forward`, which the key-off case keeps, so no test needed loosening.

## How to review

1. Run the suite — `powershell -NoProfile -File tests\Test-Plugin.ps1`. It prints
   `passed 62, failed 0, skipped 0`; 61 of those passed before this change and the
   new one is `the approved to done transition states both merge shapes`. Run; it
   is the output above.
2. Read `skills/task/SKILL.md`, **Transitions**, `approved` → `done`. This is the
   change that matters: the branch-and-no-request bullet now splits into the
   squash case with its three commands and the fast-forward case, and the other
   two bullets say the key decides nothing there.
3. Read the **Configuration** section in the same file for why `squash_on_merge`
   is called out as *not* a ceiling, unlike the other two keys.
4. `git show 784137d -- README.md docs/tasks/README.md` for the two human-facing
   tables and the paragraph that says where the key does nothing.
5. **Not run:** the squash path itself. This project sets `create_branch: false`,
   so no task here reaches a merge, and no branch was created to merge. The
   commands are stated in the protocol, not executed by it — what a reviewer can
   check is the wording, and that `-D` is justified in place.