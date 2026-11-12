---
id: audit-context
status: in_progress
priority: high
kind: task
branch: task/audit-context
---

1. run audit context and write results to a file,
2. create a plan to fix findings,
3. review plan
4. fix findings

# Implementation Plan

Step 1 is done: the audit ran and its report is
[`docs/context-audit.md`](../context-audit.md). It is committed with this plan,
because the plan is only reviewable next to the findings it answers. The report
sits in `docs/`, not `docs/tasks/`, because every `*.md` there except `README.md`
and `Tasks.md` is read as a task file and would fail the frontmatter guard.

What the audit found, shortest form: this repository imposes **no** context on a
clone — no `CLAUDE.md`, no `.claude/`, no `.mcp.json` — and the ~4,100 tokens a
session starts with all come from user-level plugin configuration. So the
repository's own waste is small and specific, and most of it is repeated
rediscovery of things nobody wrote down.

## What this task fixes

Four findings, all confirmed, all in this repository:

1. **C1 + C5 — no root context file.** Write `CLAUDE.md`, about 30 lines: what the
   repo is and that `skills/task/SKILL.md` is the single source of truth; the one
   test command; the PowerShell 5.1 constraints (`;` not `&&`, here-strings with
   `'@` at column 0, `git commit -F <file>` when the message has quotes); the file
   map for a protocol change, including the version in `.claude-plugin/plugin.json`
   and the reload-after-bump step; and the scope limits — grep
   `tests/Test-Plugin.ps1` rather than reading its ~11,900 tokens, ignore `.idea/`.
   It states **where things are, never what the rules are**: a second copy of a
   rule is finding C3.
2. **C4 — the suite prints 65 lines that no caller can filter.** Two runs in the
   last session were piped through `Select-Object -Last 8` and the full list came
   back anyway, which means the per-test lines go to the host, not the output
   stream. Switch them to `Write-Output` and add a `-Quiet` switch that prints
   failures plus the `passed N, failed N` line. The CI files keep the verbose form.
3. **C3 — `docs/tasks/Tasks.md` lines 20–34** restate the status list in a
   repository that has the plugin installed and `docs/tasks/README.md` beside it.
   Delete them. The two `skills/init/templates/` files keep theirs: they are
   shipped output and must stand alone.
4. **C7 — one line** in the new `CLAUDE.md`: after bumping the version, update and
   reload the plugin before invoking its skills here. The last session ran the
   cached **0.5.0** protocol — no `cancelled`, no `squash_on_merge` — against a
   0.8.0 repository.

## What this task does not touch

* **C2, `skills/task/SKILL.md` at ~3,420 tokens loaded in full by every skill.**
  The biggest single lever, and it already has a backlog entry —
  `reduce skill files [planning, low]` — whose body now asks exactly this. Doing
  it here would duplicate that task. Worth noting for whoever plans it: cut
  prose, not sections; the 65 tests pin the rules, not the wording.
* **C6 and C8 — MCP servers and user-level plugin settings.** The user's own
  configuration. The audit says what it costs and stops there. In particular, a
  committed `.claude/settings.json` would impose plugin choices on everyone who
  clones, which this repository deliberately does not do.

## Steps

1. `CLAUDE.md` (new, root) — as item 1 above, under 40 lines.
2. `tests/Test-Plugin.ps1` — `Write-Output` for the per-test lines, plus a
   `[switch]$Quiet` that suppresses the passing ones. The totals line always
   prints.
3. `docs/tasks/Tasks.md` — delete the status list, lines 20–34.
4. `README.md` (root) — one line under **Tests** for `-Quiet`.
5. `.claude-plugin/plugin.json` — bump `version` to `0.9.0`.
6. `tests/Test-Plugin.ps1` — two assertions: a root `CLAUDE.md` exists and names
   the test command, and it states no status name (the C3 guard, so the new file
   cannot quietly become a second copy of the protocol).
7. Run the suite and make it green.

Note on step 6: the existing `the template and this project do not drift` test
reads this project's `Tasks.md` **frontmatter** only, so step 3 should not
disturb it — but it is the one test most likely to be surprised, so run the suite
after step 3 rather than at the end only.

## Decisions

1. **A root `CLAUDE.md` is wanted** (open question 2 — answered yes).
2. **Quiet is the default, not a switch** (open question 3). The human stated they
   never run the suite themselves: only the agent does. So the default output is
   the one the agent should get — failures and the totals line — and the full
   list of cases moves behind `-Detailed`, for CI and for a human who wants it.
   This reverses step 2 of the plan, which had it opt-in.
3. **The `/context` and `/usage` figures are still missing** (open question 1,
   unanswered). Nothing in this task depends on them; section A of the report
   stays arithmetic, and section J still names them as the way to replace it.

## Open questions

1. **`/context` and `/usage` output.** Every startup number in the report is
   arithmetic on file sizes, not measurement. Pasting those two would replace
   section A with real figures and settle whether C2 or C8 is the bigger lever.
   The plan does not depend on them — findings C1, C3, C4 and C7 are confirmed
   from files — but the priority order might change.
2. **Is a root `CLAUDE.md` wanted at all?** It is startup cost on every session,
   including ones that never touch the tests, and this repository has so far
   chosen to impose nothing. The audit's judgement is that it pays for itself the
   first time it prevents an 11,900-token read, but the opposite choice is
   defensible and is yours.
3. **`-Quiet` by default, or opt-in?** The plan makes it opt-in, so CI and a human
   at a terminal are unaffected. Default-quiet would save more and surprise more.
