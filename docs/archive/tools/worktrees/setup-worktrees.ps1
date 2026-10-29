[CmdletBinding()]
param(
    [switch]$Create,
    [switch]$DryRun,
    [ValidateSet('all', '1', '2', '3', '4', '5A', '5B', '5C', '6')]
    [string]$Wave = 'all',
    [string]$Root = '',
    [string]$WorktreeRoot = '',
    [string]$BaseBranch = 'main'
)

$ErrorActionPreference = 'Stop'

if ($Create -and $DryRun) {
    throw 'Use either -Create or -DryRun, not both.'
}

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Resolve-Path (Join-Path $scriptRoot '..')).Path
}

$Root = (Resolve-Path -LiteralPath $Root).Path

if ([string]::IsNullOrWhiteSpace($WorktreeRoot)) {
    $WorktreeRoot = Join-Path $Root '.worktrees'
}

$effectiveDryRun = -not $Create
if ($DryRun) {
    $effectiveDryRun = $true
}

$branches = @(
    [pscustomobject]@{
        Wave = '1'
        ChineseName = 'Flutter scaffold'
        Branch = 'codex/flutter-scaffold'
        Directory = 'flutter-scaffold'
        Prompt = 'docs/branch-prompts/01-flutter-scaffold.md'
    },
    [pscustomobject]@{
        Wave = '2'
        ChineseName = 'Domain and data kernel'
        Branch = 'codex/domain-data-kernel'
        Directory = 'domain-data-kernel'
        Prompt = 'docs/branch-prompts/02-domain-data-kernel.md'
    },
    [pscustomobject]@{
        Wave = '3'
        ChineseName = 'Scoring main loop'
        Branch = 'codex/scoring-main-loop'
        Directory = 'scoring-main-loop'
        Prompt = 'docs/branch-prompts/03-scoring-main-loop.md'
    },
    [pscustomobject]@{
        Wave = '4'
        ChineseName = 'Replay and history'
        Branch = 'codex/replay-history'
        Directory = 'replay-history'
        Prompt = 'docs/branch-prompts/04-replay-history.md'
    },
    [pscustomobject]@{
        Wave = '5A'
        ChineseName = 'Players settings project'
        Branch = 'codex/players-settings-project'
        Directory = 'players-settings-project'
        Prompt = 'docs/branch-prompts/05-players-settings-project.md'
    },
    [pscustomobject]@{
        Wave = '5B'
        ChineseName = 'Rules audit edit'
        Branch = 'codex/rules-audit-edit'
        Directory = 'rules-audit-edit'
        Prompt = 'docs/branch-prompts/06-rules-audit-edit.md'
    },
    [pscustomobject]@{
        Wave = '5B'
        ChineseName = 'Analytics'
        Branch = 'codex/analytics'
        Directory = 'analytics'
        Prompt = 'docs/branch-prompts/07-analytics.md'
    },
    [pscustomobject]@{
        Wave = '5C'
        ChineseName = 'Export backup'
        Branch = 'codex/export-backup'
        Directory = 'export-backup'
        Prompt = 'docs/branch-prompts/08-export-backup.md'
    },
    [pscustomobject]@{
        Wave = '6'
        ChineseName = 'Release CI'
        Branch = 'codex/release-ci'
        Directory = 'release-ci'
        Prompt = 'docs/branch-prompts/09-release-ci.md'
    }
)

if ($Wave -eq 'all') {
    $selectedBranches = $branches
} else {
    $selectedBranches = $branches | Where-Object { $_.Wave -eq $Wave }
}

if (-not $selectedBranches) {
    throw "No branches selected for wave '$Wave'."
}

function Invoke-RepoGit {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & git -C $Root @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$repoTop = (& git -C $Root rev-parse --show-toplevel)
if ($LASTEXITCODE -ne 0) {
    throw "Root is not a git repository: $Root"
}
$repoTop = (Resolve-Path -LiteralPath $repoTop.Trim()).Path
if ($repoTop -ne $Root) {
    throw "Root must be the repository top-level directory. Expected $repoTop, got $Root"
}

Write-Output "Repository: $Root"
Write-Output "Worktree root: $WorktreeRoot"
Write-Output "Base branch: $BaseBranch"
Write-Output "Wave: $Wave"

if ($effectiveDryRun) {
    Write-Output 'DRY RUN: no branches or worktrees will be created.'
    foreach ($item in $selectedBranches) {
        $path = Join-Path $WorktreeRoot $item.Directory
        Write-Output ("DRY RUN: {0} ({1}) -> {2}" -f $item.ChineseName, $item.Branch, $path)
        Write-Output ("         Prompt: {0}" -f (Join-Path $Root $item.Prompt))
    }
    exit 0
}

& git -C $Root check-ignore -q '.worktrees/'
if ($LASTEXITCODE -ne 0) {
    throw '.worktrees/ must be ignored before creating project-local worktrees. Add it to .gitignore first.'
}

New-Item -ItemType Directory -Force -Path $WorktreeRoot | Out-Null

foreach ($item in $selectedBranches) {
    $path = Join-Path $WorktreeRoot $item.Directory
    $promptPath = Join-Path $Root $item.Prompt

    if (-not (Test-Path -LiteralPath $promptPath)) {
        throw "Missing prompt file for $($item.Branch): $promptPath"
    }

    if (Test-Path -LiteralPath $path) {
        Write-Output "SKIP: $($item.ChineseName) already exists at $path"
        continue
    }

    & git -C $Root show-ref --verify --quiet "refs/heads/$($item.Branch)"
    $branchExists = $LASTEXITCODE -eq 0

    if ($branchExists) {
        Invoke-RepoGit -Arguments @('worktree', 'add', $path, $item.Branch)
    } else {
        Invoke-RepoGit -Arguments @('worktree', 'add', $path, '-b', $item.Branch, $BaseBranch)
    }

    Write-Output "CREATED: $($item.ChineseName)"
    Write-Output "  Branch: $($item.Branch)"
    Write-Output "  Path: $path"
    Write-Output "  Prompt: $promptPath"
}
