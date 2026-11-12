# task-plugin

A Claude Code plugin: a backlog-to-branch task protocol. No application, nothing
to build. `skills/task/SKILL.md` is the single source of truth for the protocol —
read it there, change it there. **This file says where things are, never what the
rules are**; a second copy of a rule is worse than no copy.

## Tests

```
powershell -NoProfile -File tests\Test-Plugin.ps1
```

The only command in this repository. It prints failures and a totals line; add
`-Detailed` for every case, which is what CI runs.

The suite is ~950 lines. To change one case, grep for its name or the nearest
`Assert-` and read around the hit — reading the file whole costs more than the
change. Nothing in `.idea/` is worth exploring.

## What a change to the protocol touches

| File | What it holds |
| :- | :- |
| `skills/task/SKILL.md` | the rules |
| `skills/next-task`, `clean-tasks`, `init` | the skills that load them |
| `skills/init/templates/` | what a new project gets; must stand alone |
| `docs/tasks/README.md` | the human's view of the same pipeline |
| `README.md` | the plugin's own front page and its configuration table |
| `tests/Test-Plugin.ps1` | the guards that keep all of the above in step |
| `.claude-plugin/plugin.json` | `version`, bumped with every change |

After bumping the version, update and reload the plugin — `/plugin`, then
`/reload-plugins` — before invoking its skills here. Otherwise the cached older
copy runs against the newer repository.

## Shell

Windows PowerShell 5.1.

* No `&&` or `||`: use `;`, and `if ($?) { ... }` to chain on success.
* Here-strings (`@'...'@`), closing `'@` at column 0. No heredocs.
* A commit message containing quotes goes in a file: `git commit -F <path>`.
