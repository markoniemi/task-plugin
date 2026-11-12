# Unit tests for the `task` plugin.
#
#   powershell -File tests/Test-Plugin.ps1              failures and totals only
#   powershell -File tests/Test-Plugin.ps1 -Detailed    every case, by section
#
# Plain PowerShell: Pester is not assumed to be installed. Exits 1 on any failure.
#
# Quiet is the default because the agent is what runs this suite, and 65 passing
# lines tell it nothing it can act on. CI passes -Detailed, where a full log is
# worth having. Everything goes to the output stream, never to the host, so a
# caller can filter it.

param([switch] $Detailed)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$script:Passed = 0
$script:Failed = 0
$script:Skipped = 0

function Write-Section {
    param([string] $Name)

    if ($Detailed) { Write-Output $Name }
}

function Test-Case {
    param([string] $Name, [scriptblock] $Body)

    try {
        & $Body
        $script:Passed++
        if ($Detailed) { Write-Output "  PASS  $Name" }
    }
    catch {
        $script:Failed++
        Write-Output "  FAIL  $Name"
        Write-Output "        $($_.Exception.Message)"
    }
}

function Skip-Case {
    param([string] $Name, [string] $Reason)

    # A skip always prints: it is the one line that says a case did not run.
    $script:Skipped++
    Write-Output "  SKIP  $Name ($Reason)"
}

function Assert-True {
    param([bool] $Condition, [string] $Message)

    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string] $Message)

    if ($Expected -ne $Actual) { throw "$Message - expected '$Expected', got '$Actual'" }
}

function Get-JsonFile {
    param([string] $RelativePath)

    $path = Join-Path $root $RelativePath
    Assert-True (Test-Path $path) "$RelativePath is missing"
    return (Get-Content $path -Raw | ConvertFrom-Json)
}

function Get-SkillFrontmatter {
    param([string] $SkillName)

    $path = Join-Path $root "skills/$SkillName/SKILL.md"
    Assert-True (Test-Path $path) "skills/$SkillName/SKILL.md is missing"

    $lines = Get-Content $path
    Assert-Equal '---' $lines[0].Trim() "skills/$SkillName/SKILL.md must start with frontmatter"

    $fields = @{}
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { return $fields }
        if ($lines[$i] -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
            $fields[$matches[1]] = $matches[2].Trim()
        }
    }
    throw "skills/$SkillName/SKILL.md has no closing frontmatter delimiter"
}

$skillNames = @('task', 'next-task', 'clean-tasks', 'init')

Write-Section 'plugin manifest'

Test-Case 'plugin.json declares the plugin as `task`' {
    $manifest = Get-JsonFile '.claude-plugin/plugin.json'
    Assert-Equal 'task' $manifest.name 'plugin name'
    Assert-True (-not [string]::IsNullOrWhiteSpace($manifest.version)) 'version must be set'
    Assert-True (-not [string]::IsNullOrWhiteSpace($manifest.description)) 'description must be set'
    Assert-True (-not [string]::IsNullOrWhiteSpace($manifest.author.name)) 'author.name must be set'
}

Write-Section 'marketplace manifest'

Test-Case 'marketplace.json lists the plugin at the repository root' {
    $marketplace = Get-JsonFile '.claude-plugin/marketplace.json'
    Assert-Equal 'task-plugin' $marketplace.name 'marketplace name'
    Assert-True (-not [string]::IsNullOrWhiteSpace($marketplace.owner.name)) 'owner.name must be set'
    Assert-True (-not [string]::IsNullOrWhiteSpace($marketplace.description)) 'description must be set'

    $entries = @($marketplace.plugins)
    Assert-Equal 1 $entries.Count 'one plugin entry'
    Assert-Equal 'task' $entries[0].name 'entry name'
    Assert-Equal './' $entries[0].source 'entry source'
}

Write-Section 'skills'

foreach ($name in $skillNames) {
    $skill = $name
    Test-Case "skills/$skill/SKILL.md has frontmatter naming the skill" {
        $fields = Get-SkillFrontmatter $skill
        Assert-Equal $skill $fields['name'] "frontmatter name of $skill"
        Assert-True (-not [string]::IsNullOrWhiteSpace($fields['description'])) "description of $skill must be set"
    }
}

Test-Case 'the task skill takes the task name as an argument' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    Assert-True ($body -match '\$ARGUMENTS') 'skills/task/SKILL.md must reference $ARGUMENTS'
}

Write-Section 'protocol carried over from AGENTS.md'

Test-Case 'every status name survives in the task skill' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    foreach ($status in @('draft', 'planning', 'planned', 'in_progress', 'in_review',
                          'changes_requested', 'approved', 'done', 'cancelled')) {
        Assert-True ($body -match [regex]::Escape($status)) "status '$status' is missing"
    }
}

Test-Case 'the task skill states the task file shape and the backlog mirror' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    foreach ($rule in @('Tasks.md', 'branch:', 'priority:')) {
        Assert-True ($body -match [regex]::Escape($rule)) "rule '$rule' is missing"
    }
}

Test-Case 'next-task states the selection rule' {
    $body = Get-Content (Join-Path $root 'skills/next-task/SKILL.md') -Raw
    Assert-True ($body -match 'file:') 'next-task must skip entries that already have a file: line'
    Assert-True ($body -match 'priority') 'next-task must order by priority'
}

Test-Case 'clean-tasks keeps its two guards' {
    $body = Get-Content (Join-Path $root 'skills/clean-tasks/SKILL.md') -Raw
    Assert-True ($body -match 'done') 'clean-tasks must only delete done tasks'
    Assert-True ($body -match 'never') 'clean-tasks must keep the "never on your own" guard'
}

Write-Section 'the plugin replaces docs/tasks/AGENTS.md'

Test-Case 'docs/tasks/AGENTS.md is deleted' {
    Assert-True (-not (Test-Path (Join-Path $root 'docs/tasks/AGENTS.md'))) 'docs/tasks/AGENTS.md still exists'
}

Test-Case 'no living file names AGENTS.md as the rules' {
    # Task files are records of work already done and may mention it as history;
    # the files a reader is sent to for the rules may not.
    # The plugin's own README is exempt: it says there is no AGENTS.md, which is
    # the point.
    $living = @((Join-Path $root 'docs/tasks/README.md'), (Join-Path $root 'CLAUDE.md'))

    $hits = @(Select-String -Path $living -Pattern 'AGENTS\.md' |
        ForEach-Object { "$($_.Filename):$($_.LineNumber)" })

    # In Tasks.md only the preamble counts, not the backlog entries' own wording.
    $lines = Get-Content (Join-Path $root 'docs/tasks/Tasks.md')
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+Backlog') { break }
        if ($lines[$i] -match 'AGENTS\.md') { $hits += "Tasks.md:$($i + 1)" }
    }

    if ($hits.Count -gt 0) {
        throw "AGENTS.md is still named as the rules in $($hits -join ', ')"
    }
}

$script:ConfigDefaults = @{ create_branch = $true; create_pull_request = $false
                            squash_on_merge = $true }
$script:ConfigOptionKeys = @('type', 'title', 'description', 'required', 'default',
                             'options', 'multiple', 'sensitive', 'min', 'max')

function Get-TaskConfig {
    param([string] $Text)

    $config = @{}
    foreach ($key in $script:ConfigDefaults.Keys) { $config[$key] = $script:ConfigDefaults[$key] }

    $lines = $Text -split "`r?`n"
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $config }

    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { return $config }
        if ($lines[$i] -match '^([A-Za-z0-9_-]+):\s*(\S+)\s*$') {
            $key = $matches[1]
            $value = $matches[2]
            if (-not $config.ContainsKey($key)) { continue }
            if ($value -eq 'true') { $config[$key] = $true }
            elseif ($value -eq 'false') { $config[$key] = $false }
            else { throw "$key must be true or false, not '$value'" }
        }
    }
    throw 'the frontmatter has no closing delimiter'
}

Write-Section 'heading-derived task ids'

function Get-TaskSlug {
    param([string] $Heading)

    return ($Heading.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
}

function Test-TaskSlug {
    param([string] $Slug)

    return ($Slug -cmatch '^[a-z0-9][a-z0-9-]*[a-z0-9]$') -and ($Slug.Length -le 60)
}

function Get-TaskFiles {
    $dir = Join-Path $root 'docs/tasks'
    if (-not (Test-Path $dir)) { return @() }

    return @(Get-ChildItem -Path $dir -Filter '*.md' -File |
        Where-Object { $_.Name -ne 'README.md' -and $_.Name -ne 'Tasks.md' })
}

function Get-Frontmatter {
    param([string] $Path)

    $lines = Get-Content $Path
    Assert-Equal '---' $lines[0].Trim() "$Path must start with frontmatter"

    $fields = @{}
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { return $fields }
        if ($lines[$i] -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
            $fields[$matches[1]] = $matches[2].Trim()
        }
    }
    throw "$Path has no closing frontmatter delimiter"
}

Test-Case 'the protocol states the slug rule and the stop-and-ask' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    Assert-True ($body -match [regex]::Escape('^[a-z0-9][a-z0-9-]*[a-z0-9]$')) 'the slug pattern is missing'
    # The phrase may be wrapped across lines, so match across whitespace.
    Assert-True ($body -match 'ask\s+the\s+human\s+to\s+edit\s+the\s+heading') 'the stop-and-ask on a bad heading is missing'
}

Test-Case 'no skill prescribes the numbered scheme any more' {
    foreach ($name in @('task', 'next-task')) {
        $body = Get-Content (Join-Path $root "skills/$name/SKILL.md") -Raw
        foreach ($dead in @('task-NNN', 'task/NNN-', 'next free number')) {
            Assert-True (-not ($body -match [regex]::Escape($dead))) "skills/$name/SKILL.md still prescribes '$dead'"
        }
    }
}

Test-Case 'the protocol states which files are task files' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    Assert-True ($body -match [regex]::Escape('*.md')) 'the scan rule must name every *.md'
    Assert-True ($body -match 'except') 'the scan rule must state an exception'
    Assert-True ($body -match 'README\.md' -and $body -match 'Tasks\.md') 'README.md and Tasks.md must be excluded'
}

Test-Case 'every task file states id, status, priority and branch' {
    # An empty task directory is a legal state, and this assertion used to deny it:
    # every task may have been cleaned, leaving a backlog of drafts and no task
    # file at all. What must hold is that each file present carries the keys.
    Assert-True (Test-Path (Join-Path $root 'docs/tasks')) 'docs/tasks is missing'
    $files = Get-TaskFiles

    # branch: is there only when the project permits a branch per task.
    $keys = @('id', 'status', 'priority')
    if ((Get-TaskConfig (Get-Content (Join-Path $root 'docs/tasks/Tasks.md') -Raw))['create_branch']) {
        $keys += 'branch'
    }

    $statuses = @('draft', 'planning', 'planned', 'in_progress', 'in_review',
                  'changes_requested', 'approved', 'done', 'cancelled')
    foreach ($file in $files) {
        $fm = Get-Frontmatter $file.FullName
        foreach ($key in $keys) {
            Assert-True ($fm.ContainsKey($key)) "$($file.Name) has no $key"
        }
        Assert-True ($statuses -contains $fm['status']) "$($file.Name) has an unknown status '$($fm['status'])'"
        Assert-True (@('high', 'medium', 'low') -contains $fm['priority']) "$($file.Name) has an unknown priority '$($fm['priority'])'"
    }
}

Test-Case 'every task id is its file name' {
    foreach ($file in (Get-TaskFiles)) {
        $fm = Get-Frontmatter $file.FullName
        $id = $fm['id']
        Assert-Equal $file.BaseName $id "$($file.Name): id must equal the file name"
        Assert-True (Test-TaskSlug $id) "$($file.Name): id '$id' does not match the slug rule"
        Assert-True (-not ($id -cmatch '^task-\d{3}$')) "$($file.Name): the numbered scheme is gone, id '$id' revives it"
    }
}

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Test-Case 'every branch name is a legal git ref' {
        foreach ($file in (Get-TaskFiles)) {
            $branch = (Get-Frontmatter $file.FullName)['branch']
            if ([string]::IsNullOrWhiteSpace($branch)) { continue }
            $null = & $git.Source check-ref-format "refs/heads/$branch"
            if ($LASTEXITCODE -ne 0) { throw "$($file.Name): '$branch' is not a legal branch name" }
        }
    }
}
else {
    Skip-Case 'every branch name is a legal git ref' 'git is not on PATH'
}

Test-Case 'slug derivation follows the rule' {
    $cases = @(
        @{ Heading = 'task id/name';           Slug = 'task-id-name' },
        @{ Heading = 'feature vs task';        Slug = 'feature-vs-task' },
        @{ Heading = '  Spaces  and--dashes '; Slug = 'spaces-and-dashes' },
        @{ Heading = 'C# & .NET';              Slug = 'c-net' }
    )
    foreach ($case in $cases) {
        $slug = Get-TaskSlug $case.Heading
        Assert-Equal $case.Slug $slug "slug of '$($case.Heading)'"
        Assert-True (Test-TaskSlug $slug) "slug '$slug' must pass the rule"
    }
}

Test-Case 'a heading that cannot make a slug is rejected' {
    Assert-True (-not (Test-TaskSlug (Get-TaskSlug '???'))) 'a heading with no letters or digits must be rejected'
    Assert-True (-not (Test-TaskSlug (Get-TaskSlug 'a'))) 'a one-character slug must be rejected'
    Assert-True (-not (Test-TaskSlug ('x' * 61))) 'a slug longer than 60 characters must be rejected'
}

Write-Section 'plugin configuration'


Test-Case 'the manifest declares all three configuration options' {
    $manifest = Get-JsonFile '.claude-plugin/plugin.json'
    Assert-True ($null -ne $manifest.userConfig) 'plugin.json must declare userConfig'

    foreach ($pair in @(@('create_branch', $true), @('create_pull_request', $false),
                        @('squash_on_merge', $true))) {
        $option = $manifest.userConfig.($pair[0])
        Assert-True ($null -ne $option) "userConfig.$($pair[0]) is missing"
        Assert-Equal 'boolean' $option.type "type of $($pair[0])"
        Assert-Equal $pair[1] $option.default "default of $($pair[0])"
        Assert-True (-not [string]::IsNullOrWhiteSpace($option.title)) "title of $($pair[0])"
        Assert-True (-not [string]::IsNullOrWhiteSpace($option.description)) "description of $($pair[0])"
    }
}

Test-Case 'no userConfig option carries a key Claude Code would reject' {
    # userConfig options are strict objects: an unknown key stops the plugin loading.
    $manifest = Get-JsonFile '.claude-plugin/plugin.json'
    foreach ($option in $manifest.userConfig.PSObject.Properties) {
        foreach ($field in $option.Value.PSObject.Properties.Name) {
            Assert-True ($script:ConfigOptionKeys -contains $field) "userConfig.$($option.Name).$field is not a documented field"
        }
    }
}

Test-Case 'the protocol states the keys, the layers and the precedence' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    foreach ($rule in @('create_branch', 'create_pull_request', 'squash_on_merge',
                        'Tasks.md', '${user_config.', 'frontmatter', 'recedence')) {
        Assert-True ($body -match [regex]::Escape($rule)) "the configuration section must state '$rule'"
    }
}

Test-Case 'the protocol states that a key is a ceiling, not a default' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    Assert-True ($body -match 'ceiling') 'the ceiling reading is missing'
    Assert-True ($body -match 'contradiction') 'the create_pull_request without create_branch case is missing'
}

Test-Case 'the branch path survives the rewrite' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    # Wrapped prose: match across whitespace, so the test does not dictate the wrap.
    Assert-True ($body -match 'create\s+the\s+branch\s+named\s+in') 'the protocol must still create the branch named in branch:'
    Assert-True ($body -match 'fast-forward') 'the local merge must still be stated'
}

Test-Case 'the request path names both hosts and their commands' {
    # The request path is in a file the protocol names rather than in the protocol:
    # create_pull_request is off by default, so those words are not worth reading on
    # every invocation. Both are searched, or moving it would look like deleting it.
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    $referenced = Get-Content (Join-Path $root 'skills/task/references/host.md') -Raw
    $both = $body + "`n" + $referenced
    foreach ($rule in @('gh pr create', 'gh pr view', 'glab mr create', 'glab mr view', 'origin')) {
        Assert-True ($both -match [regex]::Escape($rule)) "the request path must name '$rule'"
    }
    Assert-True (-not ($both -match 'uses no pull requests')) 'the "no pull requests" sentence must be gone'
}

Test-Case 'both transitions that need the host file name it' {
    # Moving the request path out is the one cut that could make the agent do less
    # rather than say less: it only works if the transition that needs the file says
    # so at the moment it needs it.
    Assert-True (Test-Path (Join-Path $root 'skills/task/references/host.md')) 'skills/task/references/host.md is missing'
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    Assert-True (-not ($body -match '(?m)^##\s+The host')) 'the request path must not be back in the protocol'

    foreach ($pair in @(@('in_progress', 'in_review'), @('approved', 'done'))) {
        $pattern = '(?s)\n\*\*\x60' + $pair[0] + '.{0,30}' + $pair[1] + '(.*?)(?=\n\*\*\x60|\n##\s)'
        $step = [regex]::Match($body, $pattern).Value
        Assert-True ($step.Length -gt 0) "the $($pair[0]) to $($pair[1]) transition was not found"
        Assert-True ($step -match 'references/host\.md') "the $($pair[0]) to $($pair[1]) transition must name references/host.md"
    }
}

Test-Case 'the approved to done transition states both merge shapes' {
    # squash_on_merge only means anything where the agent merges itself, so the
    # commands and the no-ops belong in that transition, not just in the table.
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    $pattern = '(?s)\n\*\*\x60approved.{0,30}done(.*?)(?=\n\*\*\x60|\n##\s)'
    $step = [regex]::Match($body, $pattern).Value
    Assert-True ($step.Length -gt 0) 'the approved to done transition was not found'

    foreach ($rule in @('squash_on_merge', 'git merge --squash', 'git branch -D',
                        'git branch -d', 'fast-forward')) {
        Assert-True ($step -match [regex]::Escape($rule)) "the transition must state '$rule'"
    }
    # The squashed commit's message belongs to the project, not to this plugin: the
    # command takes a message, and the protocol says nothing about its shape.
    Assert-True ($step -match [regex]::Escape('git commit -m "<message>"')) 'the squash must commit with a message of its own'
    foreach ($template in @('-m "<kind>', '<kind>: <title>', '<kind>: <id>')) {
        Assert-True (-not ($step -match [regex]::Escape($template))) "the transition must not template the message with '$template'"
    }
    # The two paths the agent does not merge on must say the key decides nothing,
    # or the agent is left to guess at squashing a history it does not own.
    Assert-True ($step -match 'the host merges it, not you') 'the request path must still be the host-s'
    Assert-True (-not ($step -match 'gh pr merge')) 'the agent must not merge the request itself'
}

Test-Case 'the squashed commit message is the project-s, not the plugin-s' {
    # The protocol says nothing about the message's shape: the agent writes it the
    # way it writes any commit in the repository. Rules about subjects, moods,
    # lengths or type prefixes belong to the project, so the protocol must not grow
    # them - and it must not spend the tokens either, since it is read every time.
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    $pattern = '(?s)\n\*\*\x60approved.{0,30}done(.*?)(?=\n\*\*\x60|\n##\s)'
    $step = [regex]::Match($body, $pattern).Value
    Assert-True ($step.Length -gt 0) 'the approved to done transition was not found'

    foreach ($prescription in @('Conventional Commit', 'imperative', 'subject line',
                                '50 char', '72 char', 'backlog heading')) {
        Assert-True (-not ($step -match [regex]::Escape($prescription))) "the transition must not prescribe '$prescription'"
    }

    # Where the knowledge does belong: the human-facing README, which is read by a
    # person once rather than by the agent on every invocation.
    $readme = Get-Content (Join-Path $root 'docs/tasks/README.md') -Raw
    Assert-True ($readme -match 'conventions') 'docs/tasks/README.md must say the message follows the project-s conventions'
    Assert-True ($readme -match 'CLAUDE\.md') 'docs/tasks/README.md must name where a project states a format'
}

Test-Case 'cancelling is human-only and never rewrites what landed' {
    # The whole value of the status is that it costs nothing to set. An agent that
    # cancels by itself, or that reverts main to make a cancellation true, makes it
    # expensive instead.
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    $pattern = '(?s)\n\*\*any.{0,30}cancelled(.*?)(?=\n\*\*\x60|\n##\s)'
    $step = [regex]::Match($body, $pattern).Value
    Assert-True ($step.Length -gt 0) 'the cancelled transition was not found'

    Assert-True ($step -match 'human only') 'cancelling must be stated as human only'
    Assert-True ($step -match 'git branch -D') 'the unmerged branch must be deleted'
    Assert-True ($step -match 'Never revert') 'the transition must refuse to undo what landed'

    # Naming git revert to hand it to the human is the point; prescribing it as a
    # command of this transition is what must not happen. Commands this protocol
    # tells the agent to run are in fenced blocks, so that is where to look.
    foreach ($block in [regex]::Matches($step, '(?s)\x60\x60\x60(.*?)\x60\x60\x60')) {
        foreach ($forbidden in @('git revert', 'git reset', 'git push')) {
            Assert-True (-not ($block.Groups[1].Value -match [regex]::Escape($forbidden))) "the cancelled transition prescribes '$forbidden'"
        }
    }
}

Test-Case 'clean-tasks deletes cancelled tasks and keeps the done guard' {
    $body = Get-Content (Join-Path $root 'skills/clean-tasks/SKILL.md') -Raw
    Assert-True ($body -match 'cancelled') 'clean-tasks must name the cancelled status'
    # The check that a rule outlives its task file is the skill's reason to exist;
    # exempting cancelled tasks must not quietly exempt everything.
    Assert-True ($body -match 'written down') 'clean-tasks must keep the check that a rule is written down'
    Assert-True ($body -match 'only when a human|Only when you ask|when a human\s+asks') 'clean-tasks must stay human-triggered'
}

Test-Case 'the sections the other skills point at still exist' {
    # Cutting prose is cheap to get wrong: these headings are referred to by name,
    # from this file and from the other three skills.
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    foreach ($section in @('Task files', 'Kinds', 'Creating a task', 'Backlog mirror',
                           'Configuration', 'Lazy branches', 'Transitions')) {
        $found = $body -match ('(?m)^##\s+' + [regex]::Escape($section) + '\s*$')
        Assert-True $found "the protocol lost its '$section' section"
    }
}

Test-Case 'configuration is read from the frontmatter over the defaults' {
    $cases = @(
        @{ Name = 'no frontmatter';  Text = "# Task Backlog`n`ntext";                       Branch = $true;  Pr = $false; Squash = $true },
        @{ Name = 'branch off';      Text = "---`ncreate_branch: false`n---`n# Backlog";    Branch = $false; Pr = $false; Squash = $true },
        @{ Name = 'request on';      Text = "---`ncreate_pull_request: true`n---`n";        Branch = $true;  Pr = $true;  Squash = $true },
        @{ Name = 'squash off';      Text = "---`nsquash_on_merge: false`n---`n# Backlog";  Branch = $true;  Pr = $false; Squash = $false },
        @{ Name = 'both set';        Text = "---`ncreate_branch: false`ncreate_pull_request: true`n---`n"; Branch = $false; Pr = $true; Squash = $true },
        @{ Name = 'all three set';   Text = "---`ncreate_branch: true`ncreate_pull_request: false`nsquash_on_merge: false`n---`n"; Branch = $true; Pr = $false; Squash = $false },
        @{ Name = 'unknown key';     Text = "---`nwhatever: 3`n---`n";                      Branch = $true;  Pr = $false; Squash = $true },
        @{ Name = 'not at the top';  Text = "# Backlog`n`n---`nsquash_on_merge: false`n---`n"; Branch = $true; Pr = $false; Squash = $true }
    )
    foreach ($case in $cases) {
        $config = Get-TaskConfig $case.Text
        Assert-Equal $case.Branch $config['create_branch'] "create_branch with $($case.Name)"
        Assert-Equal $case.Pr $config['create_pull_request'] "create_pull_request with $($case.Name)"
        Assert-Equal $case.Squash $config['squash_on_merge'] "squash_on_merge with $($case.Name)"
    }
}

Test-Case 'a value that is not a boolean is rejected' {
    $rejected = $false
    try { Get-TaskConfig "---`ncreate_branch: yes`n---`n" }
    catch { $rejected = $true }
    Assert-True $rejected 'create_branch: yes must be rejected, not guessed at'
}

Test-Case 'this project states its own configuration' {
    $text = Get-Content (Join-Path $root 'docs/tasks/Tasks.md') -Raw
    Assert-True ($text.TrimStart() -match '^---') 'docs/tasks/Tasks.md must open with the configuration frontmatter'

    $config = Get-TaskConfig $text
    foreach ($key in @('create_branch', 'create_pull_request', 'squash_on_merge')) {
        Assert-True ($config[$key] -is [bool]) "$key must be a boolean"
    }
}

Write-Section 'the init skill'

function Get-TemplatePath {
    param([string] $Name)

    return (Join-Path $root "skills/init/templates/$Name")
}

Test-Case 'both templates exist' {
    foreach ($name in @('Tasks.md', 'README.md')) {
        Assert-True (Test-Path (Get-TemplatePath $name)) "skills/init/templates/$name is missing"
    }
}

Test-Case 'the backlog template is a valid backlog' {
    $text = Get-Content (Get-TemplatePath 'Tasks.md') -Raw
    Assert-True ($text.TrimStart() -match '^---') 'the template must open with the configuration frontmatter'

    $config = Get-TaskConfig $text
    Assert-Equal $true $config['create_branch'] 'the template default for create_branch'
    Assert-Equal $false $config['create_pull_request'] 'the template default for create_pull_request'
    Assert-Equal $true $config['squash_on_merge'] 'the template default for squash_on_merge'

    foreach ($status in @('draft', 'planning', 'planned', 'in_progress', 'in_review',
                          'changes_requested', 'approved', 'done', 'cancelled')) {
        Assert-True ($text -match [regex]::Escape($status)) "the template must name the status '$status'"
    }
    foreach ($priority in @('high', 'medium', 'low')) {
        Assert-True ($text -match [regex]::Escape($priority)) "the template must name the priority '$priority'"
    }

    Assert-True ($text -match '(?m)^##\s+Backlog\s*$') 'the template must have a Backlog heading'
    $after = ($text -split '(?m)^##\s+Backlog\s*$')[1]
    Assert-True (-not ($after -match '(?m)^###\s')) 'the template must hold no backlog entry'
}

Test-Case 'the template and this project do not drift' {
    $template = Get-Content (Get-TemplatePath 'Tasks.md') -Raw
    $mine = Get-Content (Join-Path $root 'docs/tasks/Tasks.md') -Raw

    foreach ($shared in @('draft', 'planning', 'planned', 'in_progress', 'in_review',
                          'changes_requested', 'approved', 'done', 'cancelled',
                          'create_branch', 'create_pull_request')) {
        Assert-True ($template -match [regex]::Escape($shared)) "the template is missing '$shared'"
    }
    foreach ($key in @('create_branch', 'create_pull_request')) {
        Assert-True ($mine -match [regex]::Escape($key)) "this project's Tasks.md is missing '$key'"
    }

    # The template states the statuses because a new project's backlog is the only
    # thing its reader has. This project has the plugin installed, so its own
    # Tasks.md points at the protocol instead of repeating it. Drift here is the
    # preamble growing its own copy of the statuses back; the brackets on the
    # entries are the mirror, and another case checks those.
    Assert-True ($mine -match [regex]::Escape('skills/task/SKILL.md')) "this project's Tasks.md must point at the protocol for the statuses"

    $restated = @()
    $mineLines = $mine -split "`r?`n"
    for ($i = 0; $i -lt $mineLines.Count; $i++) {
        if ($mineLines[$i] -match '^##\s+Backlog') { break }
        foreach ($status in @('draft', 'planning', 'planned', 'in_progress', 'in_review',
                              'changes_requested', 'approved', 'cancelled')) {
            if ($mineLines[$i] -match [regex]::Escape($status)) { $restated += "line $($i + 1): $status" }
        }
    }
    Assert-True ($restated.Count -eq 0) "this project's Tasks.md restates the statuses instead of pointing at them ($($restated -join '; '))"

    # The template states every key; a project need not. An omitted key falls back
    # to the human's own answer and then to the default, so leaving out one that
    # decides nothing here - squash_on_merge with create_branch: false - is a legal
    # state, not drift. What would be drift is a key the template never names.
    Assert-True ($template -match 'squash_on_merge') 'the template is missing squash_on_merge'

    $lines = ($mine -split "`r?`n")
    Assert-Equal '---' $lines[0].Trim() "this project's Tasks.md must open with the frontmatter"
    for ($i = 1; $i -lt $lines.Count -and $lines[$i].Trim() -ne '---'; $i++) {
        if ($lines[$i] -match '^([A-Za-z0-9_-]+):') {
            Assert-True ($template -match [regex]::Escape($matches[1])) "this project states '$($matches[1])', which the template never names"
        }
    }
    foreach ($text in @($template, $mine)) {
        Assert-True ($text -match '(?m)^##\s+Backlog\s*$') 'both must have a Backlog heading'
        Assert-True ($text -match 'Priorities') 'both must state the priorities'
    }
}

Test-Case 'the README template points at the plugin, not at itself' {
    $text = Get-Content (Get-TemplatePath 'README.md') -Raw
    foreach ($rule in @('task', '/task:task', '/task:next-task', 'Tasks.md')) {
        Assert-True ($text -match [regex]::Escape($rule)) "the README template must mention '$rule'"
    }
    Assert-True (-not ($text -match 'AGENTS\.md')) 'the README template must not mention AGENTS.md'
}

Test-Case 'the init skill states its two guards' {
    $body = Get-Content (Join-Path $root 'skills/init/SKILL.md') -Raw
    Assert-True ($body -match 'templates') 'the skill must copy the templates'
    Assert-True ($body -match 'overwrite|change nothing|already exists') 'the skill must refuse to overwrite an existing Tasks.md'
    Assert-True ($body -match 'task file') 'the skill must say it writes no task file'
}

Test-Case 'the plugin advertises four skills' {
    $readme = Get-Content (Join-Path $root 'README.md') -Raw
    Assert-True ($readme -match [regex]::Escape('/task:init')) 'README.md must list /task:init'

    $marketplace = Get-JsonFile '.claude-plugin/marketplace.json'
    Assert-True (-not ($marketplace.plugins[0].description -match 'three skills')) 'the marketplace entry still says three skills'
}

Test-Case 'the protocol makes branch: conditional when it creates a task' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    $step = [regex]::Match($body, '(?s)\d\. Write `docs/tasks/<slug>\.md`.*?\n\d\. ').Value
    Assert-True ($step.Length -gt 0) 'the Creating a task step that writes the file was not found'
    Assert-True ($step -match 'create_branch') 'that step must make branch: conditional on create_branch'
}


Test-Case 'the implementation transition owns the documentation' {
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    # The block runs from the planned heading to the next transition heading, and
    # the phrases are matched across whitespace: the test must not dictate where
    # the prose wraps, nor how many paragraphs a transition takes.
    $step = [regex]::Match($body, '(?s)planned.{0,10}in_progress.{0,4}\*\*(.*?)(?=\n\*\*\x60)').Value
    Assert-True ($step.Length -gt 0) 'the planned to in_progress transition was not found'
    Assert-True ($step -match 'documentation') 'that transition must say the implementation updates the documentation'

    $clean = Get-Content (Join-Path $root 'skills/clean-tasks/SKILL.md') -Raw
    Assert-True ($clean -match 'not\s+this\s+skill') 'clean-tasks must say keeping documentation correct is not its job'
    Assert-True ($clean -match 'never\s+as\s+part\s+of\s+reaching') 'clean-tasks must keep its never-on-your-own guard'
}
Test-Case 'the review handover is part of reaching in_review' {
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    # Each block runs to the next transition heading, which starts with a backtick;
    # bold text inside the prose does not. Phrases are matched across whitespace:
    # the test must not dictate where the prose wraps.
    $step = [regex]::Match($body, '(?s)in_progress.{0,10}in_review.{0,4}\*\*(.*?)(?=\n\*\*\x60)').Value
    Assert-True ($step.Length -gt 0) 'the in_progress to in_review transition was not found'
    Assert-True ($step -match '##\s+How\s+to\s+review') 'that transition must name the How to review section'
    Assert-True ($step -match 'not\s+run') 'that transition must require a step that was not run to say so'
    Assert-True ($step -match 'restate') 'that transition must cap the section, not restating the plan or the Result'

    $appr = [regex]::Match($body, '(?s)in_review.{0,10}approved.{0,4}\*\*(.*?)(?=\n\*\*\x60)').Value
    Assert-True ($appr.Length -gt 0) 'the in_review to approved transition was not found'
    Assert-True ($appr -match 'How\s+to\s+review') 'that transition must point the human at the section'
    Assert-True ($appr -match 'approved.{0,40}signal|signal') 'that transition must say approved is the whole signal'
}

Test-Case 'a How to review section is never an empty heading' {
    foreach ($file in Get-TaskFiles) {
        $text = ([System.IO.File]::ReadAllText($file.FullName, (New-Object System.Text.UTF8Encoding($false)))) -replace "`r`n", "`n"
        $m = [regex]::Match($text, '(?s)\n##\s+How to review\s*\n(.*?)(?=\n#|\z)')
        if (-not $m.Success) { continue }
        Assert-True ($m.Groups[1].Value.Trim().Length -gt 0) "$($file.Name) has a How to review heading with nothing under it"
    }
}
Write-Section 'kinds and the heading prefix'

$script:TaskKinds = @('feature', 'bug', 'task')

function Split-TaskHeading {
    param([string] $Heading)

    # Accepts a whole backlog heading or a bare title: the leading hashes and the
    # trailing brackets are dropped before the prefix is looked for.
    $text = (($Heading.Trim() -replace '^#+\s*', '') -replace '\s*\[[^\]]*\]\s*$', '').Trim()

    if ($text -match '^([A-Za-z]+):\s*(\S.*)$') {
        $word = $matches[1].ToLowerInvariant()
        if ($script:TaskKinds -contains $word) {
            return @{ Kind = $word; Title = $matches[2].Trim() }
        }
    }
    return @{ Kind = 'task'; Title = $text }
}

function Get-EntryBrackets {
    param([string] $Heading)

    if (-not ($Heading -match '\[([^\]]*)\]\s*$')) { throw "no brackets in '$Heading'" }
    $fields = @(($matches[1] -split ',') | ForEach-Object { $_.Trim() })
    if ($fields.Count -ne 2) {
        throw "the brackets hold exactly two fields, got $($fields.Count) in '$Heading'"
    }
    return @{ Status = $fields[0]; Priority = $fields[1] }
}

function Get-BacklogHeadings {
    $inBacklog = $false
    $found = @()
    foreach ($line in (Get-Content (Join-Path $root 'docs/tasks/Tasks.md'))) {
        if ($line -match '^##\s+Backlog') { $inBacklog = $true; continue }
        if ($inBacklog -and $line -match '^###\s+(.+)$') { $found += $matches[1] }
    }
    return $found
}

Test-Case 'a heading prefix names the kind, and its absence means task' {
    $cases = @(
        @{ Heading = 'feature: add a login page';     Kind = 'feature'; Title = 'add a login page' },
        @{ Heading = 'bug: duplicate invoice rows';   Kind = 'bug';     Title = 'duplicate invoice rows' },
        @{ Heading = 'task: bump the plugin version'; Kind = 'task';    Title = 'bump the plugin version' },
        @{ Heading = 'Feature: Add A Login Page';     Kind = 'feature'; Title = 'Add A Login Page' },
        @{ Heading = '### bug: rows [draft, high]';   Kind = 'bug';     Title = 'rows' },
        @{ Heading = 'bump the plugin version';       Kind = 'task';    Title = 'bump the plugin version' }
    )
    foreach ($case in $cases) {
        $parsed = Split-TaskHeading $case.Heading
        Assert-Equal $case.Kind $parsed.Kind "kind of '$($case.Heading)'"
        Assert-Equal $case.Title $parsed.Title "title of '$($case.Heading)'"
    }
}

Test-Case 'the slug comes from the title, never from the prefix' {
    $parsed = Split-TaskHeading 'feature: add a login page'
    $slug = Get-TaskSlug $parsed.Title
    Assert-Equal 'add-a-login-page' $slug 'the prefix must be stripped before the slug is derived'
    Assert-Equal 'feature/add-a-login-page' "$($parsed.Kind)/$slug" 'the branch must not carry the kind twice'
    Assert-True (Test-TaskSlug $slug) 'the stripped slug must still pass the rule'
}

Test-Case 'a colon after anything but a kind is part of the title' {
    # hotfix is the one that matters: it was named in the backlog entry and is
    # deliberately not a kind, so it must read as an ordinary title.
    foreach ($case in @(
        @{ Heading = 'fix: parser crash';    Title = 'fix: parser crash';    Slug = 'fix-parser-crash' },
        @{ Heading = 'hotfix: token expiry'; Title = 'hotfix: token expiry'; Slug = 'hotfix-token-expiry' },
        @{ Heading = 'chore: bump';          Title = 'chore: bump';          Slug = 'chore-bump' }
    )) {
        $parsed = Split-TaskHeading $case.Heading
        Assert-Equal 'task' $parsed.Kind "'$($case.Heading)' is a task, not a fourth kind"
        Assert-Equal $case.Title $parsed.Title "title of '$($case.Heading)'"
        Assert-Equal $case.Slug (Get-TaskSlug $parsed.Title) "slug of '$($case.Heading)'"
    }
}

Test-Case 'a task file with no kind: key is a task' {
    foreach ($file in (Get-TaskFiles)) {
        $fm = Get-Frontmatter $file.FullName
        $kind = $fm['kind']
        if ([string]::IsNullOrWhiteSpace($kind)) { $kind = 'task' }
        Assert-True ($script:TaskKinds -contains $kind) "$($file.Name) has an unknown kind '$kind'"
    }
}

Test-Case 'the protocol names the three kinds and what each branch is called' {
    $body = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    foreach ($kind in $script:TaskKinds) {
        Assert-True ($body -match [regex]::Escape("$kind/<slug>")) "the protocol must say a $kind branch is called $kind/<slug>"
    }
    Assert-True ($body -match 'no\s+prefix\s+means') 'the protocol must state the default kind'
    Assert-True ($body -match 'stripped') 'the protocol must say the prefix is stripped before the slug'
    Assert-True (-not ($body -match 'hotfix/<slug>')) 'hotfix is not a kind and has no branch of its own'
}

Test-Case 'every branch name is its kind and its id' {
    foreach ($file in (Get-TaskFiles)) {
        $fm = Get-Frontmatter $file.FullName
        $branch = $fm['branch']
        if ([string]::IsNullOrWhiteSpace($branch)) { continue }
        $kind = $fm['kind']
        if ([string]::IsNullOrWhiteSpace($kind)) { $kind = 'task' }
        Assert-Equal "$kind/$($fm['id'])" $branch "$($file.Name): branch must be <kind>/<id>"
    }
    # Stated for all three kinds as well, so the rule is still tested in a project
    # like this one, where create_branch is off and no task file carries a branch.
    foreach ($kind in $script:TaskKinds) {
        $parsed = Split-TaskHeading "${kind}: add a login page"
        Assert-Equal "$kind/add-a-login-page" "$($parsed.Kind)/$(Get-TaskSlug $parsed.Title)" "derived branch for $kind"
    }
}

if ($git) {
    Test-Case 'a branch name for every kind is a legal git ref' {
        foreach ($kind in $script:TaskKinds) {
            $null = & $git.Source check-ref-format "refs/heads/$kind/add-a-login-page"
            if ($LASTEXITCODE -ne 0) { throw "$kind/add-a-login-page is not a legal branch name" }
        }
    }
}
else {
    Skip-Case 'a branch name for every kind is a legal git ref' 'git is not on PATH'
}

Test-Case 'the brackets hold exactly two fields' {
    $headings = Get-BacklogHeadings
    Assert-True ($headings.Count -gt 0) 'docs/tasks/Tasks.md holds no backlog entries'
    foreach ($heading in $headings) {
        $brackets = Get-EntryBrackets $heading
        Assert-True (-not [string]::IsNullOrWhiteSpace($brackets.Status)) "'$heading' has no status"
        Assert-True (-not [string]::IsNullOrWhiteSpace($brackets.Priority)) "'$heading' has no priority"
    }
    $rejected = $false
    try { Get-EntryBrackets '### add a login page [draft, high, feature]' } catch { $rejected = $true }
    Assert-True $rejected 'a third bracket field must be rejected: the kind lives in the heading'
}

Test-Case 'a heading prefix matches its task file kind' {
    foreach ($heading in (Get-BacklogHeadings)) {
        $parsed = Split-TaskHeading $heading
        $path = Join-Path $root "docs/tasks/$(Get-TaskSlug $parsed.Title).md"
        if (-not (Test-Path $path)) { continue }
        $fm = Get-Frontmatter $path
        $kind = $fm['kind']
        if ([string]::IsNullOrWhiteSpace($kind)) { $kind = 'task' }
        Assert-Equal $parsed.Kind $kind "$(Split-Path -Leaf $path): kind must mirror the heading prefix"
    }
}

Write-Section 'the status decides whether a plan is required'

Test-Case 'the protocol states both routes out of draft, and both are human only' {
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    $step = [regex]::Match($body, '(?s)\n\*\*\x60draft(.*?)(?=\n\*\*\x60planning)').Value
    Assert-True ($step.Length -gt 0) 'the draft transition was not found'
    Assert-True ($step -match 'planning') 'draft must offer the planning route'
    Assert-True ($step -match 'planned') 'draft must offer the straight-to-planned route'
    Assert-True ($step -match 'human\s+only') 'both routes out of draft are human only'
}

Test-Case 'the protocol says planned without a plan means implement it' {
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    $step = [regex]::Match($body, '(?s)\n\*\*\x60planned.{0,30}in_progress(.*?)(?=\n\*\*\x60)').Value
    Assert-True ($step.Length -gt 0) 'the planned to in_progress transition was not found'
    Assert-True ($step -match 'Implementation\s+Plan') 'that transition must read whether a plan section is there'
    Assert-True ($body -match 'reject') 'the protocol must say how a human rejects a plan'
    Assert-True ($body -match 'no\s+kind\s+skips') 'the protocol must say no kind skips human review'
    # No test asserts that a planned task has a plan section. That invariant is
    # deliberately gone: planned means cleared to implement, with or without one.
}

Test-Case 'the branch is created only when there is something to commit' {
    $body = (Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw) -replace "`r`n", "`n"
    Assert-True ($body -match 'something\s+to\s+commit') 'the protocol must create the branch lazily'
    Assert-True ($body -match 'does\s+not\s+assert') 'branch: must name the branch without asserting it exists'
}

Test-Case 'the entry link is named file:, not plan:' {
    $task = Get-Content (Join-Path $root 'skills/task/SKILL.md') -Raw
    Assert-True ($task -match [regex]::Escape('file: [<slug>.md](<slug>.md)')) 'the protocol must write a file: link'

    foreach ($name in @('task', 'next-task', 'clean-tasks')) {
        $body = Get-Content (Join-Path $root "skills/$name/SKILL.md") -Raw
        Assert-True (-not ($body -match 'plan:')) "skills/$name/SKILL.md still names the entry link plan:"
        Assert-True ($body -match 'file:') "skills/$name/SKILL.md must name the entry link file:"
    }

    foreach ($path in @('docs/tasks/Tasks.md', 'skills/init/templates/Tasks.md', 'docs/tasks/README.md')) {
        $text = Get-Content (Join-Path $root $path) -Raw
        Assert-True (-not ($text -match 'plan:')) "$path still carries a plan: line"
    }
}

Test-Case 'the backlog template documents the kinds and the plan-skipping route' {
    $text = Get-Content (Get-TemplatePath 'Tasks.md') -Raw
    foreach ($kind in $script:TaskKinds) {
        Assert-True ($text -match [regex]::Escape("${kind}:")) "the template must name the kind '$kind'"
    }
    Assert-True ($text -match 'file:') 'the template must name the file: link'
    Assert-True ($text -match 'no\s+prefix') 'the template must state the default kind'
    Assert-True ($text -match 'with\s+no\s+plan') 'the template must say planned with no plan means implement it'
}
Write-Section 'the GitHub build'

$script:WorkflowPath = '.github/workflows/build.yml'

Test-Case 'a workflow runs the unit tests on a Windows runner' {
    $path = Join-Path $root $script:WorkflowPath
    Assert-True (Test-Path $path) "$script:WorkflowPath is missing"
    $text = (Get-Content $path -Raw) -replace "`r`n", "`n"

    Assert-True ($text -match '(?m)^on:') 'the workflow must state its triggers'
    Assert-True ($text -match 'push') 'the workflow must run on push'
    Assert-True ($text -match 'pull_request') 'the workflow must run on pull requests'
    Assert-True ($text -match 'actions/checkout@v\d+') 'the workflow must check the repository out'
    Assert-True ($text -match [regex]::Escape('tests/Test-Plugin.ps1')) 'the workflow must run the test script'
}

Test-Case 'the suite is never run on a runner that cannot run it' {
    # Test-Plugin.ps1 is Windows PowerShell: here-strings, powershell.exe, CRLF.
    $text = (Get-Content (Join-Path $root $script:WorkflowPath) -Raw) -replace "`r`n", "`n"
    Assert-True ($text -match 'runs-on:\s*windows-') 'the job must run on a Windows runner'
    Assert-True (-not ($text -match 'ubuntu|macos')) 'no job may run the suite on a non-Windows runner'
    Assert-True ($text -match 'powershell') 'the workflow must invoke Windows PowerShell by name'
}

Test-Case 'the workflow needs nothing the runner does not have' {
    # The suite skips the validate case when the claude CLI is absent, so the
    # workflow must not depend on it: installing and authenticating that CLI is
    # its own task, not part of a build. A comment may name it; a step may not,
    # so the comments are dropped before looking.
    $lines = @((Get-Content (Join-Path $root $script:WorkflowPath)) |
        Where-Object { $_ -notmatch '^\s*#' })
    $live = $lines -join "`n"
    Assert-True (-not ($live -match 'claude')) 'no step may invoke the claude CLI'
    Assert-True (-not ($live -match 'npm|pip|choco')) 'the workflow must install nothing to run the suite'
}

Test-Case 'the README says the tests also run in CI' {
    $readme = Get-Content (Join-Path $root 'README.md') -Raw
    Assert-True ($readme -match [regex]::Escape('tests/Test-Plugin.ps1')) 'README.md must document the test command'
    Assert-True ($readme -match [regex]::Escape($script:WorkflowPath)) "README.md must name $script:WorkflowPath"
}
Write-Section 'the repository tells an agent where things are'

$script:ClaudeMdPath = 'CLAUDE.md'

Test-Case 'a root CLAUDE.md names the test command and the source of truth' {
    $path = Join-Path $root $script:ClaudeMdPath
    Assert-True (Test-Path $path) 'CLAUDE.md is missing from the repository root'
    $text = (Get-Content $path -Raw) -replace "`r`n", "`n"

    Assert-True ($text -match 'Test-Plugin\.ps1') 'CLAUDE.md must name the test command'
    Assert-True ($text -match '-Detailed') 'CLAUDE.md must name the switch that prints every case'
    Assert-True ($text -match [regex]::Escape('skills/task/SKILL.md')) 'CLAUDE.md must point at the protocol as the single source of truth'
    Assert-True ($text -match [regex]::Escape('.claude-plugin/plugin.json')) 'CLAUDE.md must name where the version is bumped'
}

Test-Case 'CLAUDE.md says where things are, not what the rules are' {
    # The audit that produced this file found the protocol restated in five
    # places. CLAUDE.md must not become a sixth: it names files, never statuses.
    $text = Get-Content (Join-Path $root $script:ClaudeMdPath) -Raw
    $statuses = @('draft', 'planning', 'planned', 'in_progress', 'in_review',
                  'changes_requested', 'approved', 'cancelled')
    $named = @($statuses | Where-Object { $text -match [regex]::Escape($_) })
    Assert-True ($named.Count -eq 0) "CLAUDE.md states the status $($named -join ', '), which skills/task/SKILL.md owns alone"
}

Test-Case 'the suite is quiet unless asked, and writes to the output stream' {
    $text = (Get-Content (Join-Path $root 'tests/Test-Plugin.ps1') -Raw) -replace "`r`n", "`n"
    # Assembled, because the literal would otherwise be in the file it forbids.
    $host_write = 'Write' + '-Host'

    Assert-True ($text -match [regex]::Escape('param([switch] $Detailed)')) 'the suite must take a -Detailed switch'
    Assert-True (-not ($text -match $host_write)) 'the suite must write to the output stream, so that a caller can filter it'
    Assert-True ($text -match [regex]::Escape('Write-Output "passed')) 'the totals line must print whether or not -Detailed was passed'

    $readme = Get-Content (Join-Path $root 'README.md') -Raw
    Assert-True ($readme -match '-Detailed') 'README.md must document the switch'
}

Write-Section 'claude plugin validate'

$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) {
    Test-Case 'claude plugin validate passes' {
        $output = & $claude.Source plugin validate $root
        if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
    }
}
else {
    Skip-Case 'claude plugin validate passes' 'claude is not on PATH'
}

Write-Output ''
Write-Output "passed $script:Passed, failed $script:Failed, skipped $script:Skipped"

if ($script:Failed -gt 0) { exit 1 }
exit 0
