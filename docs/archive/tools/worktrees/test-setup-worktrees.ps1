$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$setupScript = Join-Path $PSScriptRoot 'setup-worktrees.ps1'
$tempWorktreeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hoopito-worktree-test-" + [guid]::NewGuid().ToString('N'))

if (-not (Test-Path -LiteralPath $setupScript)) {
    throw "Missing setup script: $setupScript"
}

$output = & $setupScript -DryRun -Root $repoRoot -WorktreeRoot $tempWorktreeRoot 2>&1
$outputText = ($output | Out-String)

$expectedBranches = @(
    'codex/flutter-scaffold',
    'codex/domain-data-kernel',
    'codex/scoring-main-loop',
    'codex/replay-history',
    'codex/rules-audit-edit',
    'codex/players-settings-project',
    'codex/analytics',
    'codex/export-backup',
    'codex/release-ci'
)

foreach ($branch in $expectedBranches) {
    if ($outputText -notmatch [regex]::Escape($branch)) {
        throw "Dry run output did not mention expected branch: $branch"
    }
}

if ($outputText -notmatch 'DRY RUN') {
    throw 'Dry run output must clearly state DRY RUN.'
}

if (Test-Path -LiteralPath $tempWorktreeRoot) {
    throw "Dry run should not create worktree root: $tempWorktreeRoot"
}

Write-Host 'setup-worktrees dry-run validation passed'
