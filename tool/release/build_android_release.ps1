[CmdletBinding()]
param(
    [string]$Version = "",
    [switch]$SkipChecks
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "release_helpers.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$keyPropertiesPath = Join-Path $repoRoot "android\key.properties"
$generatedRegistrant = Join-Path $repoRoot "android\app\src\main\java\io\flutter\plugins\GeneratedPluginRegistrant.java"
$sourceApk = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-release.apk"
$pubspec = Get-Content -Raw (Join-Path $repoRoot "pubspec.yaml")
$appMetadata = Get-Content -Raw (Join-Path $repoRoot "lib\app\app_metadata.dart")
$expectedApplicationId = "io.github.x1a0y4ngren.hooptrace"
$expectedFlutterVersion = "3.41.9"
$expectedFlutterFrameworkRevision = "00b0c91f06209d9e4a41f71b7a512d6eb3b9c694"
$expectedJavaVersion = "17.0.20+8"
$expectedCompileSdk = "36"
$expectedTargetSdk = "36"
$expectedBuildToolsVersion = "36.1.0"
$expectedNdkVersion = "28.2.13676358"
$expectedGradleVersion = "8.14"
$expectedGradleWrapperSha256 = "7d3a4ac4de1c32b59bc6a4eb8ecb8e612ccd0cf1ae1e99f66902da64df296172"
$expectedGradleDistributionSha256 = "efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1"

function Resolve-AndroidSdkPath {
    param([string]$Root)

    $androidSdk = $env:ANDROID_SDK_ROOT
    if (-not $androidSdk) { $androidSdk = $env:ANDROID_HOME }
    if (-not $androidSdk) {
        $localPropertiesPath = Join-Path $Root "android\local.properties"
        if (Test-Path -LiteralPath $localPropertiesPath) {
            $localProperties = Get-Content -LiteralPath $localPropertiesPath
            $sdkLine = $localProperties |
                Where-Object { $_ -like "sdk.dir=*" } |
                Select-Object -First 1
            if ($sdkLine) {
                $androidSdk = $sdkLine.Substring("sdk.dir=".Length).Replace("\\", "\")
            }
        }
    }
    if (-not $androidSdk) {
        throw "Android SDK path could not be resolved."
    }
    return (Resolve-Path -LiteralPath $androidSdk).Path
}

function Assert-FixedReleaseToolchain {
    param(
        [string]$Root,
        [string]$AndroidSdk
    )

    $flutterOutput = & flutter --version --machine 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect the Flutter toolchain." }
    try {
        $flutterVersion = ($flutterOutput | Out-String | ConvertFrom-Json)
    } catch {
        throw "Flutter did not return machine-readable version information."
    }
    if ($flutterVersion.frameworkVersion -ne $expectedFlutterVersion) {
        throw "Flutter $expectedFlutterVersion is required; found $($flutterVersion.frameworkVersion)."
    }
    if ($flutterVersion.frameworkRevision -ne $expectedFlutterFrameworkRevision) {
        throw "Flutter framework revision $expectedFlutterFrameworkRevision is required; found $($flutterVersion.frameworkRevision)."
    }

    $javaOutputLines = & java -version 2>&1
    $javaExitCode = $LASTEXITCODE
    $javaOutput = $javaOutputLines | Out-String
    if ($javaExitCode -ne 0 -or
        $javaOutput -notmatch [regex]::Escape($expectedJavaVersion) -or
        $javaOutput -notmatch "Temurin|Eclipse Adoptium") {
        throw "Temurin Java $expectedJavaVersion is required. Output: $javaOutput"
    }

    foreach ($relativePath in @(
        "platforms\android-$expectedCompileSdk",
        "build-tools\$expectedBuildToolsVersion",
        "ndk\$expectedNdkVersion"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $AndroidSdk $relativePath))) {
            throw "Pinned Android SDK component is missing: $relativePath"
        }
    }

    $gradleConfig = Get-Content -Raw (Join-Path $Root "android\app\build.gradle.kts")
    if ($gradleConfig -notmatch "(?m)^\s*compileSdk\s*=\s*$expectedCompileSdk\s*$") {
        throw "android/app/build.gradle.kts must pin compileSdk to $expectedCompileSdk."
    }
    if ($gradleConfig -notmatch "(?m)^\s*targetSdk\s*=\s*$expectedTargetSdk\s*$") {
        throw "android/app/build.gradle.kts must pin targetSdk to $expectedTargetSdk."
    }
    $buildToolsPattern = '(?m)^\s*buildToolsVersion\s*=\s*"' +
        [regex]::Escape($expectedBuildToolsVersion) + '"\s*$'
    if ($gradleConfig -notmatch $buildToolsPattern) {
        throw "android/app/build.gradle.kts must pin build-tools to $expectedBuildToolsVersion."
    }
    $ndkPattern = '(?m)^\s*ndkVersion\s*=\s*"' +
        [regex]::Escape($expectedNdkVersion) + '"\s*$'
    if ($gradleConfig -notmatch $ndkPattern) {
        throw "android/app/build.gradle.kts must pin NDK to $expectedNdkVersion."
    }

    $wrapperJar = Join-Path $Root "android\gradle\wrapper\gradle-wrapper.jar"
    if (-not (Test-Path -LiteralPath $wrapperJar)) {
        throw "Gradle wrapper JAR is missing."
    }
    $wrapperHash = (Get-FileHash -LiteralPath $wrapperJar -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($wrapperHash -ne $expectedGradleWrapperSha256) {
        throw "Gradle wrapper JAR SHA-256 mismatch: $wrapperHash"
    }
    $wrapperProperties = Get-Content -Raw (Join-Path $Root "android\gradle\wrapper\gradle-wrapper.properties")
    if ($wrapperProperties -notmatch [regex]::Escape("gradle-$expectedGradleVersion-all.zip")) {
        throw "Gradle wrapper must use Gradle $expectedGradleVersion all distribution."
    }
    if ($wrapperProperties -notmatch [regex]::Escape("distributionSha256Sum=$expectedGradleDistributionSha256")) {
        throw "Gradle wrapper distribution SHA-256 is missing or incorrect."
    }
}

function Assert-ApkContainsSqliteLibraries {
    param([string]$ApkPath)

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
    try {
        foreach ($abi in @("arm64-v8a", "armeabi-v7a", "x86_64")) {
            $entryName = "lib/$abi/libsqlite3.so"
            $entry = $archive.GetEntry($entryName)
            if (-not $entry -or $entry.Length -le 0) {
                throw "Release APK is missing a non-empty $entryName."
            }
        }
    } finally {
        $archive.Dispose()
    }
}

$versionMatch = [regex]::Match(
    $pubspec,
    "(?m)^version:\s+([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$"
)
if (-not $versionMatch.Success) {
    throw "pubspec.yaml must declare a semantic version and numeric build number."
}
$declaredVersion = $versionMatch.Groups[1].Value
$declaredBuildNumber = $versionMatch.Groups[2].Value
if ($Version -and $Version -ne $declaredVersion) {
    throw "Requested version $Version does not match pubspec.yaml version $declaredVersion."
}
$Version = $declaredVersion

$expectedMetadataVersion = "$Version+$declaredBuildNumber"
if ($appMetadata -notmatch "'$([regex]::Escape($expectedMetadataVersion))'") {
    throw "lib/app/app_metadata.dart does not match version $expectedMetadataVersion."
}

$releaseDirectory = Join-Path $repoRoot "build\release-assets\v$Version"
$releaseApkName = "Hoopito-v$Version-android.apk"
$releaseApk = Join-Path $releaseDirectory $releaseApkName

$trackedChanges = & git -C $repoRoot status --porcelain --untracked-files=all
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect Git status." }
if ($trackedChanges) {
    throw "Tracked files are not clean. Commit the release candidate before building."
}

if (-not (Test-Path -LiteralPath $keyPropertiesPath)) {
    throw "Missing android/key.properties. Run tool/release/setup_android_signing.ps1 first."
}

if ($env:HOOPITO_ALLOW_UNSIGNED_RELEASE -eq "true" -or $env:HOOPTRACE_ALLOW_UNSIGNED_RELEASE -eq "true") {
    throw "Neither HOOPITO_ALLOW_UNSIGNED_RELEASE nor its legacy alias may be enabled for an upstream release."
}

$androidSdk = Resolve-AndroidSdkPath -Root $repoRoot

Push-Location $repoRoot
try {
    if (Test-Path -LiteralPath $generatedRegistrant) {
        Remove-Item -LiteralPath $generatedRegistrant
    }

    flutter clean
    if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }

    flutter pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

    dart --packages=.dart_tool/package_config.json tool/release/verify_sqlite_source.dart
    if ($LASTEXITCODE -ne 0) { throw "Vendored SQLite verification failed." }

    Assert-FixedReleaseToolchain -Root $repoRoot -AndroidSdk $androidSdk

    if (-not $SkipChecks) {
        dart format --output=none --set-exit-if-changed .
        if ($LASTEXITCODE -ne 0) { throw "Formatting check failed." }

        flutter analyze
        if ($LASTEXITCODE -ne 0) { throw "Static analysis failed." }

        flutter test
        if ($LASTEXITCODE -ne 0) { throw "Tests failed." }
    }

    if (Test-Path -LiteralPath $generatedRegistrant) {
        Remove-Item -LiteralPath $generatedRegistrant
    }

    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw "Signed release build failed." }

    $postBuildChanges = & git -C $repoRoot status --porcelain --untracked-files=all
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect post-build Git status." }
    if ($postBuildChanges) {
        throw "Release tooling changed tracked or untracked source files."
    }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $sourceApk)) {
    throw "Release APK was not created at $sourceApk."
}
if (-not (Test-Path -LiteralPath $generatedRegistrant)) {
    throw "Flutter did not generate the Android runtime plugin registrant."
}
$registrantContent = Get-Content -Raw -LiteralPath $generatedRegistrant
if ($registrantContent -match "IntegrationTestPlugin") {
    throw "The release plugin registrant still contains integration_test."
}
$requiredRuntimePlugins = @(
    "JniPlugin",
    "JniFlutterPlugin"
)
foreach ($pluginClass in $requiredRuntimePlugins) {
    if ($registrantContent -notmatch [regex]::Escape($pluginClass)) {
        throw "The release plugin registrant is missing $pluginClass."
    }
}
Remove-Item -LiteralPath $generatedRegistrant

$buildToolsPath = Join-Path $androidSdk "build-tools\$expectedBuildToolsVersion"
$apksigner = Join-Path $buildToolsPath "apksigner.bat"
$aapt = Join-Path $buildToolsPath "aapt.exe"
if (-not (Test-Path -LiteralPath $apksigner)) { throw "apksigner was not found." }
if (-not (Test-Path -LiteralPath $aapt)) { throw "aapt was not found." }

New-Item -ItemType Directory -Force -Path $releaseDirectory | Out-Null
Copy-Item -LiteralPath $sourceApk -Destination $releaseApk -Force
Assert-ApkContainsSqliteLibraries -ApkPath $releaseApk

$packageOutput = & $aapt dump badging $releaseApk 2>&1
if ($LASTEXITCODE -ne 0) { throw "APK package metadata inspection failed." }
$packageLine = $packageOutput | Where-Object { $_ -like "package:*" } | Select-Object -First 1
if (-not $packageLine) { throw "APK package metadata was not found." }
if ($packageLine -notmatch "name='$([regex]::Escape($expectedApplicationId))'") {
    throw "APK application ID does not match $expectedApplicationId."
}
if ($packageLine -notmatch "versionCode='$([regex]::Escape($declaredBuildNumber))'") {
    throw "APK versionCode does not match $declaredBuildNumber."
}
if ($packageLine -notmatch "versionName='$([regex]::Escape($Version))'") {
    throw "APK versionName does not match $Version."
}
[IO.File]::WriteAllLines(
    (Join-Path $releaseDirectory "PACKAGE.txt"),
    [string[]]$packageOutput,
    [Text.UTF8Encoding]::new($false)
)

$certificateOutput = & $apksigner verify --verbose --print-certs $releaseApk 2>&1
if ($LASTEXITCODE -ne 0) { throw "APK signature verification failed." }
[IO.File]::WriteAllLines(
    (Join-Path $releaseDirectory "CERTIFICATE.txt"),
    [string[]]$certificateOutput,
    [Text.UTF8Encoding]::new($false)
)

$permissionOutput = & $aapt dump permissions $releaseApk 2>&1
if ($LASTEXITCODE -ne 0) { throw "APK permission inspection failed." }
[IO.File]::WriteAllLines(
    (Join-Path $releaseDirectory "PERMISSIONS.txt"),
    [string[]]$permissionOutput,
    [Text.UTF8Encoding]::new($false)
)

$hash = Get-CompatibleSha256 -LiteralPath $releaseApk
[IO.File]::WriteAllText(
    (Join-Path $releaseDirectory "SHA256SUMS"),
    "$hash  $releaseApkName`n",
    [Text.UTF8Encoding]::new($false)
)

Write-Host "Signed release assets: $releaseDirectory"
Write-Host "SHA-256: $hash"
