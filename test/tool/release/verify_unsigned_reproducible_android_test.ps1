[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
$scriptPath = Join-Path $repoRoot "tool\release\verify_unsigned_reproducible_android.ps1"
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw ($parseErrors | Out-String) }
foreach ($name in @("Get-SafeCanonicalSource", "Remove-OwnedCanonicalSource", "Test-BinaryFilesEqual", "Invoke-RecordedNative", "Assert-EffectiveFlutterToolchain", "Resolve-NativeApplication")) {
    $definition = $ast.Find({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if (-not $definition) { throw "Missing verifier helper: $name" }
    Invoke-Expression $definition.Extent.Text
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Expected)
    try { & $Action } catch {
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
        return
    }
    throw "Expected rejection containing '$Expected'."
}

$testBase = [IO.Path]::GetFullPath("D:\temp")
$workspace = Join-Path $testBase ("hoopito-reproducibility-test-" + [guid]::NewGuid().ToString("N"))
$source = Join-Path $workspace "hoopito-reproducible-source"
$token = [guid]::NewGuid().ToString("N")
New-Item -ItemType Directory -Path $workspace | Out-Null
try {
    $actual = Get-SafeCanonicalSource -WorkspaceRoot $workspace -RepoRoot $repoRoot
    if ($actual -ne $source) { throw "Canonical source did not use the fixed leaf." }
    Assert-Throws { Get-SafeCanonicalSource -WorkspaceRoot "D:\" -RepoRoot $repoRoot } "drive root"
    Assert-Throws { Get-SafeCanonicalSource -WorkspaceRoot "C:\temp" -RepoRoot $repoRoot } "D:"
    Assert-Throws { Get-SafeCanonicalSource -WorkspaceRoot "D:relative" -RepoRoot $repoRoot } "absolute"
    Assert-Throws { Get-SafeCanonicalSource -WorkspaceRoot $workspace -RepoRoot $workspace } "outside"
    Assert-Throws { Get-SafeCanonicalSource -WorkspaceRoot "D:\temp\..\Android\Sdk" -RepoRoot $repoRoot -ProtectedRoots @("D:\Android\Sdk") } "outside"

    New-Item -ItemType Directory -Path $source | Out-Null
    [IO.File]::WriteAllText((Join-Path $source "keep.txt"), "unrelated data")
    Assert-Throws { Get-SafeCanonicalSource -WorkspaceRoot $workspace -RepoRoot $repoRoot } "already exists"
    Assert-Throws { Remove-OwnedCanonicalSource -WorkspaceRoot $workspace -SourcePath $source -OwnershipToken $token } "ownership"
    if (-not (Test-Path -LiteralPath (Join-Path $source "keep.txt"))) { throw "Unowned contents were deleted." }
    [IO.File]::WriteAllText((Join-Path $source ".hoopito-reproducible-owner"), $token)
    Assert-Throws { Remove-OwnedCanonicalSource -WorkspaceRoot $workspace -SourcePath $workspace -OwnershipToken $token } "exact"
    Assert-Throws { Remove-OwnedCanonicalSource -WorkspaceRoot $workspace -SourcePath $source -OwnershipToken "different" } "ownership"
    Remove-OwnedCanonicalSource -WorkspaceRoot $workspace -SourcePath $source -OwnershipToken $token
    if (Test-Path -LiteralPath $source) { throw "Owned canonical source was not removed." }

    $target = Join-Path $workspace "junction-target"
    $junction = Join-Path $workspace "junction-parent"
    New-Item -ItemType Directory -Path $target | Out-Null
    New-Item -ItemType Junction -Path $junction -Value $target | Out-Null
    try {
        Assert-Throws { Get-SafeCanonicalSource -WorkspaceRoot $junction -RepoRoot $repoRoot } "reparse point"
        New-Item -ItemType Directory -Path $source | Out-Null
        [IO.File]::WriteAllText((Join-Path $source ".hoopito-reproducible-owner"), $token)
        $nestedJunction = Join-Path $source "linked"
        New-Item -ItemType Junction -Path $nestedJunction -Value $target | Out-Null
        try {
            Assert-Throws { Remove-OwnedCanonicalSource -WorkspaceRoot $workspace -SourcePath $source -OwnershipToken $token } "reparse point"
            if (-not (Test-Path -LiteralPath $source)) { throw "A workspace containing a junction was deleted." }
        } finally { [IO.Directory]::Delete($nestedJunction) }
        Remove-OwnedCanonicalSource -WorkspaceRoot $workspace -SourcePath $source -OwnershipToken $token
    } finally { [IO.Directory]::Delete($junction) }

    $a = Join-Path $workspace "a.bin"
    $b = Join-Path $workspace "b.bin"
    $bytes = New-Object byte[] (1024 * 1024 + 7)
    $bytes[0] = 19
    $bytes[$bytes.Length - 1] = 43
    [IO.File]::WriteAllBytes($a, $bytes)
    [IO.File]::WriteAllBytes($b, $bytes)
    if (-not (Test-BinaryFilesEqual -First $a -Second $b)) { throw "Identical files were rejected." }
    $bytes[$bytes.Length - 1] = 44
    [IO.File]::WriteAllBytes($b, $bytes)
    if (Test-BinaryFilesEqual -First $a -Second $b) { throw "A final-chunk byte difference was missed." }
    [IO.File]::WriteAllBytes($b, (New-Object byte[] 1))
    if (Test-BinaryFilesEqual -First $a -Second $b) { throw "A length difference was missed." }
    [IO.File]::WriteAllBytes($a, (New-Object byte[] 0))
    [IO.File]::WriteAllBytes($b, (New-Object byte[] 0))
    if (-not (Test-BinaryFilesEqual -First $a -Second $b)) { throw "Empty identical files were rejected." }

    $child = Join-Path $workspace "native-stderr.ps1"
    $log = Join-Path $workspace "native.log"
    [IO.File]::WriteAllText($child, '[Console]::Error.WriteLine("expected stderr"); exit 7')
    $powershellExe = (Get-Command powershell -CommandType Application).Source
    $native = Invoke-RecordedNative $powershellExe @("-NoProfile", "-File", $child) $log -AllowFailure
    if ($native.ExitCode -ne 7 -or [IO.File]::ReadAllText($log) -notlike "*expected stderr*") {
        throw "Native exit status or stderr evidence was lost."
    }
    Assert-Throws { Invoke-RecordedNative $powershellExe @("-NoProfile", "-File", $child) $log } "Native command failed (7)"

    # Flutter config --machine reports the selected Java even when jdk-dir is
    # absent from stored config and Android Studio's JBR wins over JAVA_HOME.
    $pinnedJdk = "C:\toolchains\jdk-17.0.20+8"
    $pinnedSdk = "D:\Android\Sdk"
    $selectedPinned = '{"jdk-dir":"C:\\toolchains\\jdk-17.0.20+8","android-sdk":"D:\\Android\\Sdk","android-studio-dir":"D:\\Android\\Studio"}'
    $selectedStudio = '{"jdk-dir":"D:\\Android\\Studio\\jbr","android-sdk":"D:\\Android\\Sdk","android-studio-dir":"D:\\Android\\Studio"}'
    Assert-EffectiveFlutterToolchain -MachineJson $selectedPinned -JavaHome $pinnedJdk -AndroidSdkRoot $pinnedSdk
    Assert-Throws { Assert-EffectiveFlutterToolchain -MachineJson $selectedStudio -JavaHome $pinnedJdk -AndroidSdkRoot $pinnedSdk } "selected Java"
    Assert-Throws { Assert-EffectiveFlutterToolchain -MachineJson '{"android-sdk":"D:\\Android\\Sdk"}' -JavaHome $pinnedJdk -AndroidSdkRoot $pinnedSdk } "selected Java"
    Assert-Throws { Assert-EffectiveFlutterToolchain -MachineJson '{"jdk-dir":"C:\\toolchains\\jdk-17.0.20+8","android-sdk":"C:\\Android\\Sdk"}' -JavaHome $pinnedJdk -AndroidSdkRoot $pinnedSdk } "selected Android SDK"

    # Exercise actual Get-Command resolution with two applications on PATH.
    $firstBin = Join-Path $workspace "first-bin"
    $secondBin = Join-Path $workspace "second-bin"
    New-Item -ItemType Directory -Path $firstBin, $secondBin | Out-Null
    $commandName = "hoopito_repro_test.cmd"
    [IO.File]::WriteAllText((Join-Path $firstBin $commandName), "@exit /b 0")
    [IO.File]::WriteAllText((Join-Path $secondBin $commandName), "@exit /b 0")
    [IO.File]::WriteAllText((Join-Path $firstBin "flutter.bat"), "@exit /b 0")
    [IO.File]::WriteAllText((Join-Path $firstBin "flutter"), "#!/bin/sh")
    $previousPath = $env:PATH
    try {
        $env:PATH = "$firstBin;$secondBin;$previousPath"
        $nativePath = Resolve-NativeApplication $commandName
        if ($nativePath -isnot [string] -or $nativePath -ne (Join-Path $firstBin $commandName)) {
            throw "Native resolution did not select exactly the first application."
        }
        if ((Resolve-NativeApplication "flutter") -ne (Join-Path $firstBin "flutter.bat")) {
            throw "Unqualified Flutter did not select the Windows batch executable."
        }
        if ((Resolve-NativeApplication (Join-Path $secondBin $commandName)) -ne (Join-Path $secondBin $commandName)) {
            throw "An explicitly selected application path was ignored."
        }
    } finally { $env:PATH = $previousPath }
    Write-Output "Verifier helper checks passed: paths/cleanup, bytes, native recording/resolution, effective Flutter JDK/SDK."
} finally {
    $resolved = (Resolve-Path -LiteralPath $workspace).Path
    if ($resolved -ne $workspace -or [IO.Path]::GetDirectoryName($resolved) -ne $testBase -or
        [IO.Path]::GetFileName($resolved) -notlike "hoopito-reproducibility-test-*") {
        throw "Refusing unsafe test cleanup: $resolved"
    }
    if (Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
        throw "Refusing test cleanup containing a reparse point."
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
