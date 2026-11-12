# Token usage audit — task-plugin

Run on 2026-11-12 by the `context:audit` skill, at the request of the
`audit context` task. The audit skill changes nothing itself; the task asked for
the results in a file, so this file is the only thing it wrote.

Numbers are character counts from the files, with tokens approximated as
chars ÷ 4. **No `/context` or `/usage` output was available**, so every startup
figure here is computed, not measured — see the open question in section J.

## A. Project overview

* A Claude Code **plugin**, not an application. No build tool, no modules, no
  compiled sources. 17 tracked files.
* **Instruction files: none.** No root `CLAUDE.md`, no `AGENTS.md`, no `.claude/`
  directory, no `.mcp.json`. The repository imposes nothing on a clone.
* **Skills shipped** (these are the product, and they load in the sessions of
  everyone who installs the plugin):

  | Skill | Description (startup) | Body (on invocation) |
  | :- | -: | -: |
  | `task` | 355 chars | 13,676 chars (~3,420 tok) |
  | `next-task` | 309 chars | 1,768 chars |
  | `clean-tasks` | 299 chars | 1,647 chars |
  | `init` | 297 chars | 1,577 chars |

* **Documentation**: `README.md` 196 lines, `docs/tasks/README.md` 149 lines,
  `skills/init/templates/*` 94 lines.
* **Tests**: one file, `tests/Test-Plugin.ps1`, 936 lines / 47,723 chars
  (~11,930 tok), run as
  `powershell -NoProfile -File tests\Test-Plugin.ps1`.
* **Estimated startup cost of this session**, before any file is read — none of
  it imposed by this repository:

  | Source | Chars | ~Tokens |
  | :- | -: | -: |
  | Enabled plugin skill descriptions (28 skills) | 7,062 | 1,765 |
  | `superpowers` SessionStart injection (full `using-superpowers`) | 3,192 | 800 |
  | `caveman` SessionStart block | ~1,600 | 400 |
  | MCP server instruction blocks (chrome, Claude Docs, context7) | ~4,500 | 1,125 |
  | `caveman` UserPromptSubmit line | ~150 per prompt | ~40 per prompt |

  Roughly **4,100 tokens per session** plus a per-prompt line, all of it from
  user-level configuration rather than from this repository.

## B. Executive summary

Two findings account for most of the avoidable cost, and they pull in opposite
directions.

1. **There is no root context file.** Every session rediscovers the test command,
   the PowerShell 5.1 constraints, which files restate the protocol, and where the
   version is bumped. The expensive form of that rediscovery is reading
   `tests/Test-Plugin.ps1` whole — ~11,900 tokens, which happened in this
   session. A ~400-token `CLAUDE.md` that names the test command and says *grep
   this file, never read it whole* pays for itself the first time it works.
2. **`skills/task/SKILL.md` is ~3,420 tokens and the other three skills open by
   loading it in full.** Three task operations in one session cost ~10,000 tokens
   of protocol text. This is already on the backlog as `reduce skill files`, and
   the safe cut is prose, not sections — the rules are load-bearing and 65 tests
   pin them.

Everything else is smaller: one duplicated status list, a test suite that prints
65 PASS lines per run and cannot be filtered by its caller, and user-level
settings that are the human's call rather than the repository's.

## C. Findings by category

### C1. Context files — no root instruction file

* **Finding** — no `CLAUDE.md`, `AGENTS.md` or `.claude/rules/` anywhere.
* **Evidence** — `git ls-files` lists 17 files, none of them an instruction file;
  `Test-Path CLAUDE.md` / `AGENTS.md` / `.claude` all `False`.
* **Why it costs tokens** — nothing tells a session how to run the tests, that
  PowerShell 5.1 rejects `&&` and heredocs, that `skills/task/SKILL.md` is the
  single source of truth, or which files have to change together. Each session
  derives it by reading. The costly derivation is the test file.
* **Proposed change** — a root `CLAUDE.md` of about 30 lines: what the repo is;
  the one test command; the PowerShell rules; "changing the protocol touches
  `skills/task/SKILL.md` plus the files listed in C3, the version in
  `.claude-plugin/plugin.json`, and `tests/Test-Plugin.ps1`"; and the scope limit
  from C5. Point at `docs/tasks/README.md` instead of restating it.
* **Expected benefit** — removes repeated rediscovery; prevents at least one
  ~11,900-token read.
* **Severity** high / **confidence** confirmed / **effort** small.
* **Risks** — a context file is itself startup cost, paid by every session
  including ones that never touch the tests. Keep it under ~40 lines or it starts
  costing more than it saves. It also must not drift from `SKILL.md`; keep it to
  *where things are*, never *what the rules are*.
* **Verification** — a later session asked to change one test should grep, not
  read the file whole.

### C2. Skills — the protocol file is loaded in full by every skill

* **Finding** — `skills/task/SKILL.md` is 293 lines / 14,031 chars (~3,420 tok),
  and `next-task`, `clean-tasks` and `init` each open with "Read the protocol
  first", so no task operation costs less than that.
* **Evidence** — `skills/next-task/SKILL.md:8`, `skills/clean-tasks/SKILL.md:8`;
  three invocations in this session (`clean-tasks`, `task`, `next-task`).
* **Why it costs tokens** — the whole protocol loads whatever the operation
  needs. Cleaning two files needs the statuses and the `done` rule; it also pays
  for **Kinds**, **Creating a task**, the slug regex and the host paths.
* **Proposed change** — two options, in this order:
  1. **Cut prose, keep every rule.** The file explains *why* in several places —
     the `-D` rationale, ceiling-versus-default, the `hotfix` aside, the
     colon-in-a-title aside, "Nothing else justifies `-D`". Several are 3–5 lines
     where one would do. This is the `reduce skill files` backlog entry, and it
     risks nothing: the 65 tests assert the rules, not the prose.
  2. **Then** consider moving **Kinds** (lines 56–91) to
     `skills/task/references/kinds.md`, pointed at from **Creating a task**, the
     way `host.md` already works. Measure after (1) before doing (2).
* **Expected benefit** — proportional to the cut; a quarter off the file is ~850
  tokens per task operation.
* **Severity** high / **confidence** confirmed / **effort** medium.
* **Risks** — real, for option 2. The slug rule in **Creating a task** and the
  precedence in **Configuration** are load-bearing; an agent that does not follow
  the pointer gets them wrong, and the failure is silent. `host.md` is a safe
  precedent only because both transitions that need it say "read that file now".
  Option 1 carries the opposite risk: the prose exists because it prevented a
  mistake, so cut only what no test and no past task needed.
* **Verification** — `tests/Test-Plugin.ps1` green, and the file's character
  count before and after.

### C3. Documentation — five files restate the same rules

* **Finding** — statuses, kinds and the configuration keys are stated in
  `skills/task/SKILL.md`, `docs/tasks/README.md`, root `README.md`,
  `skills/init/templates/Tasks.md` and `skills/init/templates/README.md`.
* **Evidence** — `create_branch|squash_on_merge|in_review|cancelled` matches 104
  times across 9 files; a `## Configuration` heading exists in `SKILL.md:131`,
  `docs/tasks/README.md:69` and `README.md:78`; a `## Kinds` heading in the first
  two.
* **Why it costs tokens** — a one-line protocol change edits six to eight files,
  each read before it is edited. Every task in this session did exactly that.
* **Proposed change** — the two templates must stay standalone; they are shipped
  output. The duplication worth removing is in **this project's own**
  `docs/tasks/Tasks.md`, lines 20–34: a 15-line status list, in a repository that
  has the plugin installed and a `docs/tasks/README.md` next to it. Root
  `README.md` keeps the config table (it is the plugin's advertisement) but can
  point at the protocol for the statuses.
* **Expected benefit** — fewer files per protocol change; less drift to police.
* **Severity** medium / **confidence** confirmed / **effort** medium.
* **Risks** — `the backlog template is a valid backlog` and `the template and
  this project do not drift` both read status lists. The drift test compares
  frontmatter keys only, so removing prose should be safe — but it must be
  re-run, not assumed.
* **Verification** — suite green; `git grep -c cancelled` drops.

### C4. Build and test output — 65 PASS lines per run, unfilterable

* **Finding** — the suite prints one line per test, ~2,600 chars per run, and the
  caller cannot trim it.
* **Evidence** — three runs in this session. Two of them were piped through
  `Select-Object -Last 3` and `-Last 8`, and the full 65 lines came back anyway,
  which means the script writes to the host rather than to the output stream.
* **Why it costs tokens** — every run pays for 65 lines that say nothing when
  they all pass, and no caller-side filter can stop it.
* **Proposed change** — switch the per-test lines to `Write-Output`, and add a
  `-Quiet` switch that prints only failures plus the `passed N, failed N` line:

  ```powershell
  if (-not $Quiet -or -not $ok) { Write-Output "  $status  $name" }
  ```

  Keep the verbose form in `.github/workflows/build.yml` and `.gitlab-ci.yml`,
  where a full log is worth having.
* **Expected benefit** — ~2,500 chars per run, several runs per task.
* **Severity** medium / **confidence** confirmed / **effort** small.
* **Risks** — a quiet run tells you less when something is subtly wrong; the
  failure path must still name the failing case, which is the whole point of the
  switch.
* **Verification** — run both ways; force a failure and check it still prints.

### C5. Repository exploration — the test file gets read whole

* **Finding** — `tests/Test-Plugin.ps1` is 47,723 chars (~11,930 tok) and is the
  file most likely to be opened when a test needs changing.
* **Evidence** — this session's own note: "was read before the last conversation
  was summarized, but the contents are too large to include".
* **Why it costs tokens** — one read is roughly three task operations' worth of
  protocol text, and it recurs after every compaction.
* **Proposed change** — one line in the root `CLAUDE.md` from C1: to change a
  test, grep for its case title or the nearest `Assert-` and read ±40 lines;
  never read the file whole. Also name `.idea/` as not worth exploring.
* **Expected benefit** — avoids the single largest read available in this repo.
* **Severity** high / **confidence** likely (the read happened; whether it
  recurs depends on the session) / **effort** small.
* **Risks** — a genuinely structural change to the suite does need the whole
  file; the instruction should say "to change *a test*", not "never".
* **Verification** — later sessions grep it.

### C6. MCP — nothing imposed by the repository

* **Finding** — no `.mcp.json`. The servers in play are user-level. The only one
  the repository's plugin set contributes is `context7`, whose instructions are
  ~600 chars, under the ~1,000-char threshold worth flagging.
* **Evidence** — `Test-Path .mcp.json` is `False`; `settings.json:37-44`.
* **Proposed change** — none for the repository. For sessions in this repo,
  `/mcp` can switch off servers this work never uses — the IDE server, Gmail,
  Calendar, Drive, Chrome — which drops their instruction blocks and tool names.
* **Severity** low / **confidence** confirmed / **effort** small.

### C7. Session level — stale plugin cache and a conflicting plugin config

* **Finding** — not a token finding but a correctness one, and it cost turns in
  this session. The cache holds task-plugin 0.1.0, 0.2.0, 0.4.0, 0.5.0 and
  0.8.0, and the skill invocations before the reload ran **0.5.0** — a protocol
  with no `cancelled` status and no `squash_on_merge` key, i.e. older than the
  repository it was being used on.
* **Evidence** — the invoked skill's base directory read
  `...\task-plugin\task\0.5.0\skills\task`; its **Configuration** section said
  "Two keys" and interpolated `create_branch` as `false`, while
  `docs/tasks/Tasks.md` frontmatter says `true`.
* **Why it costs tokens** — the agent follows a superseded protocol and the human
  corrects it; the correction and the re-run are the cost.
* **Proposed change** — after bumping `version` in `.claude-plugin/plugin.json`,
  update and reload the plugin before using it on this repo (`/plugin`, then
  `/reload-plugins`), which is what happened today. Worth a line in the root
  `CLAUDE.md`. Separately, `settings.json:71-78` pins
  `pluginConfigs.task@task-plugin.create_branch: false`; this repo's Tasks.md
  frontmatter outranks it, so the pinned value does nothing here and only
  misleads the interpolation. Removing it is the human's call.
* **Severity** medium / **confidence** confirmed / **effort** small.
* **Risks** — none; the reload is already routine.

### C8. Session level — user-level injections, and duplicated auto-mode entries

* **Finding** — the ~4,100 tokens in section A come entirely from user-level
  configuration. The largest single levers are the two plugins this repository's
  workflow never uses: `superpowers` (738 tok of descriptions plus the 800-tok
  SessionStart injection; four of its skills are already switched off in
  `settings.json:26-31`) and `caveman` (684 tok of descriptions plus a ~400-tok
  SessionStart block and a line on every prompt). Separately,
  `settings.json:81-113` holds an `autoMode.environment` block of ~3,500 chars in
  which "Repository visibility", "Source control" and "Sensitive data locations"
  each appear twice — once for this repo and once for `markoniemi/dvd-rip`, a
  different project.
* **Evidence** — measured per enabled plugin version:
  `caveman` 2,738 chars of descriptions, `superpowers` 2,953, `task` 1,262,
  `context` 1,109.
* **Why it costs tokens** — descriptions and SessionStart output are paid before
  the first prompt, every session, whether or not the skill is used.
* **Proposed change** — the user's call, not the repository's. If this repo's
  sessions do not use them, disable them in
  `.claude/settings.local.json` (gitignored), **not** in a committed
  `.claude/settings.json` — a committed one would impose the choice on everyone
  who clones, which this repository currently, deliberately, does not do. Prune
  the `dvd-rip` lines from `autoMode.environment`, or let auto mode re-derive
  them per repository.
* **Severity** medium / **confidence** confirmed / **effort** small.
* **Risks** — `caveman` is an explicit preference and `superpowers` supplies
  skills the user may want elsewhere; this is a preference, not a defect. Nothing
  here should be changed without the user asking.

## D. Prioritized improvement plan

| Priority | Finding | Proposed change | Effort | Confidence |
| :- | :- | :- | :- | :- |
| 1 | C1 + C5 | Root `CLAUDE.md`, ~30 lines: test command, PowerShell rules, file map, "grep the test file" | small | confirmed |
| 2 | C4 | `-Quiet` switch and `Write-Output` in the suite | small | confirmed |
| 3 | C3 | Drop the 15-line status list from `docs/tasks/Tasks.md` | medium | confirmed |
| 4 | C2 | Trim prose in `skills/task/SKILL.md` — the `reduce skill files` task | medium | confirmed |
| 5 | C7 | Reload-after-bump line in `CLAUDE.md`; drop the stale `pluginConfigs` pin | small | confirmed |
| 6 | C8 | Per-repo `settings.local.json`; prune `autoMode.environment` | small | confirmed |
| — | C6 | Nothing for the repo; `/mcp` for unused servers | small | confirmed |

## E. Recommended target structure

```
CLAUDE.md                      <- new, ~30 lines: where things are, not what the rules are
README.md                      <- keeps install, commands, config table, decisions
docs/
  context-audit.md             <- this file
  tasks/
    README.md                  <- the human's view of the pipeline
    Tasks.md                   <- backlog only; status list removed (C3)
skills/
  task/SKILL.md                <- the rules, trimmed (C2)
  task/references/host.md      <- loaded on demand; the precedent for any further split
  next-task|clean-tasks|init/SKILL.md
tests/Test-Plugin.ps1          <- -Quiet by default for agents (C4)
```

Nothing moves out of `docs/tasks/` into a new file there: every `*.md` in that
directory except `README.md` and `Tasks.md` is read as a task file and must carry
task frontmatter. That is why this report sits in `docs/`.

## F. Recommended context file changes

There is no existing context file, so this is all *missing*, not *to remove*.
A root `CLAUDE.md` should carry:

* One line on what the repository is, and that `skills/task/SKILL.md` is the
  single source of truth for the protocol.
* The test command, and that it is the only one.
* The PowerShell 5.1 constraints: no `&&`/`||`, here-strings with `'@` at column
  0, `git commit -F <file>` when the message contains quotes. (All three were
  learned the expensive way in earlier sessions.)
* The file map: what a protocol change has to touch, including the version in
  `.claude-plugin/plugin.json`.
* Scope limits: grep `tests/Test-Plugin.ps1`, do not read it whole; ignore
  `.idea/`; do not reformat files you are not changing.
* Reload the plugin after a version bump before invoking its skills here.

It should **not** restate any rule from `SKILL.md`. Two copies of a rule is the
problem C3 describes.

## G. Build scope

One command, no module scoping available or needed:

```powershell
powershell -NoProfile -File tests\Test-Plugin.ps1
```

With C4 implemented, `-Quiet` becomes the form worth putting in `CLAUDE.md`.

## H. Quick wins

* Root `CLAUDE.md` (C1, C5).
* `-Quiet` and `Write-Output` in the suite (C4).
* Delete `docs/tasks/Tasks.md` lines 20–34 (C3).

## I. Longer-term

* Trimming `skills/task/SKILL.md` without losing a rule (C2) — the
  `reduce skill files` backlog entry owns this, and it needs the test suite as
  its safety net.
* Only after measuring: moving **Kinds** into `references/`.

## J. Measurement plan

Nothing here was measured against a real session, which is this report's main
weakness.

* **Open question for the human**: paste `/context` and `/usage`. `/context`
  gives the real startup breakdown by category, which replaces every estimate in
  section A; `/usage` attributes spend to individual skills and plugins, which
  would confirm or kill C2 and C8.
* **Before/after task**: take one backlog entry from `draft` to `planned`
  — a plan-only operation, no code, so it is repeatable. Record input tokens,
  cache reads, tool calls and files opened, before the changes and after.
* Watch for the obvious failure mode: a `CLAUDE.md` that adds startup cost to
  every session while the reads it was meant to prevent happen anyway.

## K. Conclusion

Implementation order: C1+C5 together, then C4, then C3, then hand C2 to the
`reduce skill files` task. C7 is one line plus a settings deletion; C6 and C8 are
the user's own configuration and should not be touched without being asked.

The single most valuable next step is not a change at all — it is pasting
`/context` and `/usage` output, which turns section A from arithmetic into
measurement and settles whether C2 or C8 is the bigger lever.
