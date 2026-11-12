---
id: remind-to-clear-context
status: planned
priority: low
kind: task
branch: task/remind-to-clear-context
---

Is it possible to remind user to clear context after task is merged to master (or
set to done)?

# Implementation Plan

## Is it possible

Yes, two ways, and they are very different in cost.

**Nothing can clear the context for you.** No hook, skill or command can run
`/clear` on the user's behalf — it is a client action. So every answer here is a
reminder, and the question is only who emits it and how reliably.

### A. The protocol asks for it (recommended)

One sentence in the `approved` → `done` transition: having reported the task
done, tell the human that the next task starts from the backlog and needs none of
this context, so `/clear` is worth running first. Costs one line in a file the
agent reads on every invocation, and nothing else exists to maintain. It is as
reliable as the agent's compliance with the rest of the transition, which is what
every other step of this protocol already rests on.

### B. A hook the plugin ships

Claude Code hooks are real and a plugin can ship them in `hooks/hooks.json`,
merged into the user's hooks when the plugin is enabled. The fitting shape is
`PostToolUse` filtered to git commits:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "if": "Bash(git commit *)",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/remind-clear.<ext>" }
        ]
      }
    ]
  }
}
```

The script reads `git log -1 --format=%s`, and when the subject marks a task
reaching `done` it prints `{"systemMessage": "..."}` — the one output field that
addresses the user rather than the model. One commit fires it once, so it needs no
state to avoid repeating itself.

Two costs, and they are why this is not the recommendation:

* **It needs a script that runs on Windows and on POSIX.** This plugin ships no
  executables today and has no runtime to lean on: `python` may be absent, `grep`
  is absent on Windows, and `hooks.json` has no way to branch on the operating
  system. A pair of scripts with a wrapper is the usual answer, and it is a lot of
  machinery for one sentence of output.
* **It recognises `done` by parsing a commit subject**, which this protocol
  deliberately stopped prescribing in the `merge commit` task. The hook would
  reintroduce exactly the coupling that task removed.

`TaskCompleted` also exists as a hook event, but it belongs to Claude Code's own
task list, not to this plugin's task files, so it does not fire here.

## Steps

Plan A:

1. `skills/task/SKILL.md`, **Transitions**, `approved` → `done` — one line after
   the three paths: having set `done` and mirrored it, say the task is finished and
   that `/clear` before the next one is worth it, because the next task starts
   from the backlog and reuses nothing from this conversation.
2. `docs/tasks/README.md` — one sentence where the pipeline ends, so a human knows
   the suggestion comes from the protocol rather than from the AI improvising, and
   that `/compact` is the gentler option when they want the thread kept.
3. `.claude-plugin/plugin.json` — bump `version` to `0.9.0`.
4. `tests/Test-Plugin.ps1` — extend the `approved` → `done` case: the transition
   names `/clear`. One assertion; it is the only thing that could silently
   disappear.
5. Run `tests/Test-Plugin.ps1` and make it green.

With `create_branch` now on, this work goes on `task/remind-to-clear-context`,
created at the first commit, and the `done` transition squashes it into `main`.
This is the first task in this project that will exercise that path.

## Open questions

1. **A or B.** The plan assumes A. B is defensible if you want the reminder even
   when the agent forgets, and the answer then has to include which runtime the
   bundled script may use.
2. **`cancelled` too?** Cancelling also ends a task and leaves a context worth
   dropping. The plan assumes the line goes only in `done`; say if it belongs in
   both.
3. **`/clear` or `/compact`.** The plan says `/clear`, since a finished task's
   conversation is spent, and mentions `/compact` only in the README.
