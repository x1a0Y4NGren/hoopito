[CmdletBinding()]
param(
    [string]$WorkspaceRoot = "D:\Hoopito-Reproducibility",
    [string]$AndroidSdkRoot = "D:\Android\Sdk",
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$FlutterPath = "flutter"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "release_helpers.ps1")

function Get-SafeCanonicalSource {
    param([string]$WorkspaceRoot, [string]$RepoRoot, [string[]]$ProtectedRoots = @())
    if ($WorkspaceRoot -notmatch '^[A-Za-z]:[\\/]') {
        throw "The reproducibility workspace must be an absolute drive path."
    }
    $workspace = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\', '/')
    if ($workspace.Length -eq 2) { throw "The reproducibility workspace cannot be a drive root." }
    if ($workspace -notmatch '^D:\\') { throw "The Windows reproducibility workspace must be on D:." }
    foreach ($protected in (@($RepoRoot) + $ProtectedRoots)) {
        $root = [IO.Path]::GetFullPath($protected).TrimEnd('\', '/')
        if ($workspace.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
            $workspace.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase) -or
            $root.StartsWith($workspace + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw "The reproducibility workspace must be outside source and toolchain directories: $root"
        }
    }
    $ancestor = $workspace
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw "The workspace ancestry contains a file or reparse point: $ancestor"
            }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    $source = Join-Path $workspace "hoopito-reproducible-source"
    if (Test-Path -LiteralPath $source) { throw "The canonical reproducibility workspace already exists: $source" }
    return $source
}

function Remove-OwnedCanonicalSource {
    param([string]$WorkspaceRoot, [string]$SourcePath, [string]$OwnershipToken)
    $workspace = [IO.Path]::GetFullPath($WorkspaceRoot).TrimEnd('\', '/')
    $expected = Join-Path $workspace "hoopito-reproducible-source"
    $actual = [IO.Path]::GetFullPath($SourcePath).TrimEnd('\', '/')
    if ($workspace -notmatch '^D:\\' -or $workspace.Length -le 3 -or $actual -ne $expected) {
        throw "Refusing cleanup outside the exact canonical workspace: $actual"
    }
    if (-not (Test-Path -LiteralPath $actual)) { return }
    $ancestor = $actual
    while ($ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or -not $item.PSIsContainer) {
            throw "Refusing cleanup through a reparse point or file: $ancestor"
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    $resolved = (Resolve-Path -LiteralPath $actual).Path
    $marker = Join-Path $resolved ".hoopito-reproducible-owner"
    if ($resolved -ne $expected -or -not $OwnershipToken -or
        -not [IO.File]::Exists($marker) -or [IO.File]::ReadAllText($marker) -ne $OwnershipToken) {
        throw "Refusing cleanup without this invocation's ownership marker: $actual"
    }
    $reparse = Get-ChildItem -LiteralPath $resolved -Recurse -Force |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | Select-Object -First 1
    if ($reparse) { throw "Refusing recursive cleanup containing a reparse point: $($reparse.FullName)" }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

function Test-BinaryFilesEqual {
    param([string]$First, [string]$Second)
    if (-not ("HoopitoReproducibleFiles" -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
public static class HoopitoReproducibleFiles {
    public static bool Equal(string first, string second) {
        using (var a = File.OpenRead(first))
        using (var b = File.OpenRead(second)) {
            if (a.Length != b.Length) return false;
            var x = new byte[1024 * 1024];
            var y = new byte[x.Length];
            while (a.Position < a.Length) {
                int count = (int)Math.Min(x.Length, a.Length - a.Position);
                ReadChunk(a, x, count);
                ReadChunk(b, y, count);
                for (int i = 0; i < count; i++) if (x[i] != y[i]) return false;
            }
            return true;
        }
    }
    private static void ReadChunk(Stream stream, byte[] buffer, int count) {
        int offset = 0;
        while (offset < count) {
            int read = stream.Read(buffer, offset, count - offset);
            if (read == 0) throw new EndOfStreamException();
            offset += read;
        }
    }
}
'@
    }
    return [HoopitoReproducibleFiles]::Equal($First, $Second)
}

function Invoke-RecordedNative {
    param([string]$Executable, [string[]]$Arguments, [string]$LogPath, [switch]$AllowFailure)
    # Windows PowerShell treats ordinary native stderr (including java -version)
    # as ErrorRecords. Preserve it as evidence and use the native exit status.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $writer = $null
    try {
        if ($LogPath) { $writer = New-Object IO.StreamWriter($LogPath, $false, (New-Object Text.UTF8Encoding $false)) -ErrorAction Stop }
        $lines = @(& $Executable @Arguments 2>&1 | ForEach-Object {
            $line = $_.ToString()
            if ($writer) { $writer.WriteLine($line); $writer.Flush() }
            $line
        })
        $nativeExitCode = $LASTEXITCODE
    } finally {
        if ($writer) { $writer.Dispose() }
        $ErrorActionPreference = $previousPreference
    }
    if ($nativeExitCode -ne 0 -and -not $AllowFailure) {
        throw "Native command failed ($nativeExitCode): $Executable $($Arguments -join ' '). Evidence: $LogPath`n$($lines -join "`n")"
    }
    return [pscustomobject]@{ Lines = $lines; ExitCode = $nativeExitCode }
}

function Write-Evidence {
    param([string]$Path, [string[]]$Lines)
    [IO.File]::WriteAllLines($Path, $Lines, (New-Object Text.UTF8Encoding $false))
}

function Get-RunnerFingerprint {
    return "$([Environment]::OSVersion.VersionString)|$env:PROCESSOR_ARCHITECTURE|$env:COMPUTERNAME|$env:RUNNER_NAME|$env:GITHUB_RUN_ID|$env:GITHUB_RUN_ATTEMPT"
}

function Resolve-NativeApplication {
    param([string]$Name)
    if ($Name -eq "flutter") { $Name = "flutter.bat" }
    $application = Get-Command $Name -CommandType Application -ErrorAction Stop | Select-Object -First 1
    return [string]$application.Source
}

function Assert-EffectiveFlutterToolchain {
    param([string]$MachineJson, [string]$JavaHome, [string]$AndroidSdkRoot)
    $selected = $MachineJson | ConvertFrom-Json -ErrorAction Stop
    $selectedJava = $selected.'jdk-dir'
    if ($selectedJava -isnot [string] -or [string]::IsNullOrWhiteSpace($selectedJava) -or
        [IO.Path]::GetFullPath($selectedJava).TrimEnd('\', '/') -ne [IO.Path]::GetFullPath($JavaHome).TrimEnd('\', '/')) {
        throw "Flutter's selected Java must match the pinned JavaHome: $JavaHome. Inspect FLUTTER_CONFIG.json; an isolated APPDATA configuration can select the pinned JDK."
    }
    $selectedSdk = $selected.'android-sdk'
    if ($selectedSdk -isnot [string] -or [string]::IsNullOrWhiteSpace($selectedSdk) -or
        [IO.Path]::GetFullPath($selectedSdk).TrimEnd('\', '/') -ne [IO.Path]::GetFullPath($AndroidSdkRoot).TrimEnd('\', '/')) {
        throw "Flutter's selected Android SDK must match the pinned AndroidSdkRoot: $AndroidSdkRoot. Inspect FLUTTER_CONFIG.json."
    }
}

function Save-PinnedToolchain {
    param([string]$SourceRoot, [string]$Destination)
    New-Item -ItemType Directory -Path $Destination | Out-Null
    $flutterInfo = Invoke-RecordedNative $flutter @("--version", "--machine") (Join-Path $Destination "FLUTTER_TOOLCHAIN.json")
    $version = ($flutterInfo.Lines -join "`n") | ConvertFrom-Json
    if ($version.frameworkVersion -ne "3.41.9" -or
        $version.frameworkRevision -ne "00b0c91f06209d9e4a41f71b7a512d6eb3b9c694") {
        throw "Flutter 3.41.9 at framework revision 00b0c91f06209d9e4a41f71b7a512d6eb3b9c694 is required."
    }
    $javaInfo = Invoke-RecordedNative $java @("-version") (Join-Path $Destination "JAVA_TOOLCHAIN.txt")
    $javaText = $javaInfo.Lines -join "`n"
    if ($javaText -notmatch '17\.0\.20\+8(?:\D|$)' -or $javaText -notmatch 'Temurin|Eclipse Adoptium') {
        throw "Temurin Java 17.0.20+8 is required. See JAVA_TOOLCHAIN.txt."
    }
    # Machine config includes the JDK and SDK that Flutter actually selected,
    # including Android Studio's JBR taking precedence over JAVA_HOME.
    $flutterConfig = Invoke-RecordedNative $flutter @("config", "--machine") (Join-Path $Destination "FLUTTER_CONFIG.json")
    Assert-EffectiveFlutterToolchain -MachineJson ($flutterConfig.Lines -join "`n") -JavaHome $jdkRoot -AndroidSdkRoot $sdkRoot
    $gradle = Get-Content -Raw -LiteralPath (Join-Path $SourceRoot "android\app\build.gradle.kts")
    foreach ($pin in @('(?m)^\s*compileSdk\s*=\s*36\s*$', '(?m)^\s*targetSdk\s*=\s*36\s*$',
        '(?m)^\s*buildToolsVersion\s*=\s*"36\.1\.0"\s*$', '(?m)^\s*ndkVersion\s*=\s*"28\.2\.13676358"\s*$')) {
        if ($gradle -notmatch $pin) { throw "Source does not pin the expected Android toolchain: $pin" }
    }
    $settings = Get-Content -Raw -LiteralPath (Join-Path $SourceRoot "android\settings.gradle.kts")
    if ($settings -notmatch 'id\("com\.android\.application"\)\s+version\s+"8\.11\.1"') {
        throw "Android Gradle Plugin 8.11.1 is required."
    }
    $wrapperHash = Get-CompatibleSha256 (Join-Path $SourceRoot "android\gradle\wrapper\gradle-wrapper.jar")
    if ($wrapperHash -ne "7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172") {
        throw "Gradle wrapper JAR SHA-256 mismatch: $wrapperHash"
    }
    $properties = Get-Content -Raw -LiteralPath (Join-Path $SourceRoot "android\gradle\wrapper\gradle-wrapper.properties")
    if ($properties -notmatch '(?m)^distributionUrl=https\\://services\.gradle\.org/distributions/gradle-8\.14-all\.zip\s*$' -or
        $properties -notmatch '(?m)^distributionSha256Sum=efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1\s*$') {
        throw "The Gradle 8.14 distribution URL and SHA-256 must be pinned."
    }
    # Caller flags may contain proxy credentials. Fingerprint them for drift
    # detection without placing their contents in the retained evidence.
    $gradleOptionsHasher = [Security.Cryptography.SHA256]::Create()
    try {
        $gradleOptionsDigest = [BitConverter]::ToString($gradleOptionsHasher.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes([string]$env:GRADLE_OPTS))).Replace("-", "").ToLowerInvariant()
    } finally { $gradleOptionsHasher.Dispose() }
    $androidLines = @("compileSdk=36", "targetSdk=36", "buildTools=36.1.0", "ndk=28.2.13676358",
        "sdkRoot=$sdkRoot", "javaHome=$jdkRoot", "flutterExecutable=$flutter", "agp=8.11.1", "gradleVersion=8.14",
        "gradleWrapperSha256=$wrapperHash", "gradleDistributionSha256=efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1",
        "gradleUserHome=$env:GRADLE_USER_HOME", "gradleOptionsSha256=$gradleOptionsDigest",
        "pubCache=$env:PUB_CACHE", "flutterConfigHome=$env:APPDATA")
    foreach ($component in @("platforms\android-36", "build-tools\36.1.0", "ndk\28.2.13676358")) {
        $componentProperties = Join-Path (Join-Path $sdkRoot $component) "source.properties"
        if (-not [IO.File]::Exists($componentProperties)) { throw "Pinned Android SDK component is missing: $component" }
        $componentText = Get-Content -Raw -LiteralPath $componentProperties
        $requiredProperty = switch ($component) {
            "platforms\android-36" { 'AndroidVersion\.ApiLevel\s*=\s*36' }
            "build-tools\36.1.0" { 'Pkg\.Revision\s*=\s*36\.1\.0' }
            "ndk\28.2.13676358" { 'Pkg\.Revision\s*=\s*28\.2\.13676358' }
        }
        if ($componentText -notmatch ("(?m)^" + $requiredProperty + '\s*$')) {
            throw "Android SDK source.properties does not match the pinned component: $component"
        }
        $androidLines += "$component/source.properties.sha256=$(Get-CompatibleSha256 $componentProperties)"
        $androidLines += Get-Content -LiteralPath $componentProperties
    }
    Write-Evidence (Join-Path $Destination "ANDROID_TOOLCHAIN.txt") $androidLines
    Write-Evidence (Join-Path $Destination "RUNNER_IDENTITY.txt") @((Get-RunnerFingerprint))
}

function Assert-UnchangedLock {
    param([string]$SourceRoot)
    $actual = Get-CompatibleSha256 (Join-Path $SourceRoot "pubspec.lock")
    if ($actual -ne $lockHash) { throw "The committed pubspec.lock changed: expected=$lockHash actual=$actual" }
}

function Invoke-CleanBuild {
    param([string]$Label)
    $archive = Join-Path $output "source-$Label.zip"
    Invoke-RecordedNative $git @("-C", $repoRoot, "archive", "--format=zip", "--output=$archive", $sourceCommit) | Out-Null
    Write-Evidence (Join-Path $output "source-$Label.sha256") @("$(Get-CompatibleSha256 $archive)  source-$Label.zip")
    if (Test-Path -LiteralPath $canonicalSource) { throw "The canonical source unexpectedly exists: $canonicalSource" }
    New-Item -ItemType Directory -Path $canonicalSource | Out-Null
    [IO.File]::WriteAllText((Join-Path $canonicalSource ".hoopito-reproducible-owner"), $invocationId)
    try {
        [IO.Compression.ZipFile]::ExtractToDirectory($archive, $canonicalSource)
        if (Test-Path -LiteralPath (Join-Path $canonicalSource "android\key.properties")) {
            throw "Unsigned snapshots must not contain android/key.properties."
        }
        Assert-UnchangedLock $canonicalSource
        $snapshot = Join-Path $output "toolchain-$Label"
        Save-PinnedToolchain $canonicalSource $snapshot
        foreach ($name in @("FLUTTER_TOOLCHAIN.json", "JAVA_TOOLCHAIN.txt", "FLUTTER_CONFIG.json", "ANDROID_TOOLCHAIN.txt", "RUNNER_IDENTITY.txt")) {
            if (-not (Test-BinaryFilesEqual (Join-Path $reference $name) (Join-Path $snapshot $name))) {
                throw "Toolchain or runner changed before build ${Label}: $name"
            }
        }
        Push-Location $canonicalSource
        try {
            Invoke-RecordedNative $flutter @("pub", "get", "--enforce-lockfile") (Join-Path $output "pub-$Label.log") | Out-Null
            Assert-UnchangedLock $canonicalSource
            Invoke-RecordedNative $dart @("--packages=.dart_tool/package_config.json", "tool/release/verify_sqlite_source.dart") (Join-Path $output "sqlite-$Label.log") | Out-Null
            # The release-mode pub pass removes dev-only integration_test from
            # the generated Android registrant; the lock is rechecked afterward.
            Invoke-RecordedNative $flutter @("build", "apk", "--release") (Join-Path $output "build-$Label.log") | Out-Null
        } finally { Pop-Location }
        Assert-UnchangedLock $canonicalSource
        $builtApk = Join-Path $canonicalSource "build\app\outputs\flutter-apk\app-release.apk"
        if (-not [IO.File]::Exists($builtApk) -or (Get-Item -LiteralPath $builtApk).Length -eq 0) { throw "Build did not produce a non-empty release APK." }
        $apk = Join-Path $output "app-release-$Label.apk"
        Copy-Item -LiteralPath $builtApk -Destination $apk
        Write-Evidence (Join-Path $output "app-release-$Label.sha256") @("$(Get-CompatibleSha256 $apk)  app-release-$Label.apk")
        $signature = Invoke-RecordedNative $apkSigner @("verify", "--verbose", $apk) (Join-Path $output "signature-$Label.txt") -AllowFailure
        if ($signature.ExitCode -eq 0 -or ($signature.Lines -join "`n") -notmatch 'DOES NOT VERIFY') {
            throw "Expected an unsigned APK; inspect signature-$Label.txt."
        }
        Save-PinnedToolchain $canonicalSource (Join-Path $output "toolchain-$Label-after")
        foreach ($name in @("FLUTTER_TOOLCHAIN.json", "JAVA_TOOLCHAIN.txt", "FLUTTER_CONFIG.json", "ANDROID_TOOLCHAIN.txt", "RUNNER_IDENTITY.txt")) {
            if (-not (Test-BinaryFilesEqual (Join-Path $reference $name) (Join-Path $output "toolchain-$Label-after\$name"))) {
                throw "Toolchain or runner changed during build ${Label}: $name"
            }
        }
    } finally {
        Remove-OwnedCanonicalSource -WorkspaceRoot $WorkspaceRoot -SourcePath $canonicalSource -OwnershipToken $invocationId
    }
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$git = Resolve-NativeApplication "git"
$flutter = Resolve-NativeApplication $FlutterPath
$dart = Join-Path ([IO.Path]::GetDirectoryName($flutter)) "dart.bat"
if (-not [IO.File]::Exists($dart)) { throw "dart.bat must come from the selected Flutter bin directory." }
if (-not $JavaHome) { throw "Provide -JavaHome or JAVA_HOME pointing to Temurin 17.0.20+8." }
$jdkRoot = (Resolve-Path -LiteralPath $JavaHome).Path.TrimEnd('\')
$java = Join-Path $jdkRoot "bin\java.exe"
if (-not [IO.File]::Exists($java)) { throw "JavaHome does not contain bin/java.exe." }
$sdkRoot = (Resolve-Path -LiteralPath $AndroidSdkRoot).Path.TrimEnd('\')
$apkSigner = Join-Path $sdkRoot "build-tools\36.1.0\apksigner.bat"
if (-not [IO.File]::Exists($apkSigner)) { throw "Android build-tools 36.1.0 apksigner.bat is required." }
$canonicalSource = Get-SafeCanonicalSource -WorkspaceRoot $WorkspaceRoot -RepoRoot $repoRoot -ProtectedRoots @($sdkRoot, $jdkRoot, (Split-Path (Split-Path $flutter)))
$WorkspaceRoot = [IO.Path]::GetDirectoryName($canonicalSource)
$status = Invoke-RecordedNative $git @("-C", $repoRoot, "status", "--porcelain=v1", "--untracked-files=all")
if ($status.Lines.Count -ne 0) { throw "Commit all source and metadata changes before reproducibility verification." }
Invoke-RecordedNative $git @("-C", $repoRoot, "ls-files", "--error-unmatch", "--", "pubspec.lock") | Out-Null
$sourceCommit = ((Invoke-RecordedNative $git @("-C", $repoRoot, "rev-parse", "HEAD")).Lines -join '').Trim()
$trackedSigningConfig = Invoke-RecordedNative $git @("-C", $repoRoot, "ls-tree", "--name-only", $sourceCommit, "--", "android/key.properties")
if ($trackedSigningConfig.Lines.Count -ne 0) { throw "Unsigned source commits must not contain android/key.properties." }
$sourceDateEpoch = ((Invoke-RecordedNative $git @("-C", $repoRoot, "show", "-s", "--format=%ct", $sourceCommit)).Lines -join '').Trim()
if ($sourceDateEpoch -notmatch '^\d+$') { throw "Unable to derive numeric SOURCE_DATE_EPOCH from the source commit." }
$lockHash = Get-CompatibleSha256 (Join-Path $repoRoot "pubspec.lock")
$invocationId = [guid]::NewGuid().ToString("N")
$output = Join-Path $repoRoot ("build\reproducible\windows-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $invocationId.Substring(0, 8))
$reference = Join-Path $output "reference-toolchain"
New-Item -ItemType Directory -Path $output | Out-Null
New-Item -ItemType Directory -Path $WorkspaceRoot -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$savedEnvironment = @{}
foreach ($name in @("JAVA_HOME", "PATH", "ANDROID_SDK_ROOT", "ANDROID_HOME", "SOURCE_DATE_EPOCH", "HOOPITO_ALLOW_UNSIGNED_RELEASE", "GRADLE_OPTS")) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}
$protocol = @("protocolVersion=1", "sourceSnapshot=two fresh git archive exports of one commit", "commit=$sourceCommit",
    "sourceDateEpoch=$sourceDateEpoch", "pubspecLockSha256=$lockHash", "canonicalBuildRoot=$canonicalSource",
    "comparison=complete unsigned release APK bytes", "dependencyResolution=flutter pub get --enforce-lockfile; lock rechecked after build",
    "signing=disabled; no key.properties in either archive", "gradleDaemon=single-use; JVM exits before workspace cleanup",
    "sameRunner=true", "crossRunner=not tested", "crossOS=not tested")
Write-Evidence (Join-Path $output "PUBSPEC_LOCK_SHA256") @($lockHash)
Write-Evidence (Join-Path $output "REPRODUCIBILITY.txt") ($protocol + "apkComparison=incomplete")
try {
    $env:JAVA_HOME = $jdkRoot
    $env:PATH = (Join-Path $jdkRoot "bin") + ";" + $env:PATH
    $env:ANDROID_SDK_ROOT = $sdkRoot
    $env:ANDROID_HOME = $sdkRoot
    $env:SOURCE_DATE_EPOCH = $sourceDateEpoch
    $env:HOOPITO_ALLOW_UNSIGNED_RELEASE = "true"
    # A persistent Gradle JVM can retain mapped R8 output files on Windows even
    # after assembleRelease returns, preventing safe removal of the first tree.
    # A single-use JVM exits with each build; preserve the caller's other flags.
    $env:GRADLE_OPTS = ($env:GRADLE_OPTS + " -Dorg.gradle.daemon=false").Trim()
    Save-PinnedToolchain $repoRoot $reference
    Write-Host "Build a: fresh source at $canonicalSource. Evidence: $output"
    Invoke-CleanBuild "a"
    Write-Host "Build b: second fresh source at the same canonical path."
    Invoke-CleanBuild "b"
    $apkA = Join-Path $output "app-release-a.apk"
    $apkB = Join-Path $output "app-release-b.apk"
    Write-Evidence (Join-Path $output "SHA256SUMS") @("$(Get-CompatibleSha256 $apkA)  app-release-a.apk", "$(Get-CompatibleSha256 $apkB)  app-release-b.apk")
    if (-not (Test-BinaryFilesEqual $apkA $apkB)) {
        Write-Evidence (Join-Path $output "REPRODUCIBILITY.txt") ($protocol + "apkComparison=different")
        throw "Unsigned release APKs differ. Both complete APKs, hashes, logs and toolchain snapshots are retained in $output."
    }
    Copy-Item -LiteralPath $apkA -Destination (Join-Path $output "app-release.apk")
    Write-Evidence (Join-Path $output "SHA256SUMS") @("$(Get-CompatibleSha256 $apkA)  app-release.apk", "$(Get-CompatibleSha256 $apkA)  app-release-a.apk", "$(Get-CompatibleSha256 $apkB)  app-release-b.apk")
    Write-Evidence (Join-Path $output "REPRODUCIBILITY.txt") ($protocol + "apkComparison=byte-identical")
    foreach ($name in @("FLUTTER_TOOLCHAIN.json", "JAVA_TOOLCHAIN.txt", "ANDROID_TOOLCHAIN.txt")) {
        Copy-Item -LiteralPath (Join-Path $reference $name) -Destination (Join-Path $output $name)
    }
    Copy-Item -LiteralPath (Join-Path $reference "RUNNER_IDENTITY.txt") -Destination (Join-Path $output "RUNNER_IDENTITY.txt")
    Write-Host "Reproducible unsigned APK: $output\app-release.apk"
} catch {
    Write-Evidence (Join-Path $output "FAILURE.txt") @($_.Exception.Message)
    throw
} finally {
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], "Process") }
}
