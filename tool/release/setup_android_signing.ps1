[CmdletBinding()]
param(
    # Keep the released app's key location and alias across the brand change.
    [string]$KeystorePath = (Join-Path $HOME ".hooptrace\signing\hooptrace-release.jks"),
    [string]$Alias = "hooptrace",
    [string]$DistinguishedName = "CN=Hoopito, OU=Open Source, O=Hoopito, C=CN"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "release_helpers.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$keyPropertiesPath = Join-Path $repoRoot "android\key.properties"
$keytool = (Get-Command keytool -ErrorAction Stop).Source
$KeystorePath = [IO.Path]::GetFullPath($KeystorePath)
$keystoreDirectory = Split-Path -Parent $KeystorePath

if ($KeystorePath.StartsWith(
        $repoRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "The permanent release keystore must be stored outside the Git repository."
}

New-Item -ItemType Directory -Force -Path $keystoreDirectory | Out-Null

$keystoreAlreadyExists = Test-Path -LiteralPath $KeystorePath -PathType Leaf
if (-not $keystoreAlreadyExists) {
    Write-Host "Creating the permanent Hoopito Android release key."
    Write-Host "Choose a strong password and press Enter for the key password to reuse it."
    & $keytool `
        -genkeypair `
        -v `
        -keystore $KeystorePath `
        -alias $Alias `
        -storetype JKS `
        -keyalg RSA `
        -keysize 4096 `
        -validity 10000 `
        -dname $DistinguishedName
    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE."
    }
} else {
    Write-Host "Recovery mode: using the existing keystore without replacing it: $KeystorePath"
}

function ConvertFrom-SecureValue {
    param([Security.SecureString]$Value)

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

$password = Read-Host "Re-enter the password used for both the keystore and key" -AsSecureString
if ($password.Length -lt 12) {
    throw "Use a release-key password with at least 12 characters."
}
$passwordText = ConvertFrom-SecureValue $password

function ConvertTo-JavaPropertyValue {
    param([string]$Value)

    return $Value.Replace("\", "\\").Replace("`r", "\r").Replace("`n", "\n")
}

try {
    $env:HOOPITO_KEYSTORE_PASSWORD = $passwordText
    & $keytool `
        -list `
        -keystore $KeystorePath `
        -alias $Alias `
        -storepass:env HOOPITO_KEYSTORE_PASSWORD | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "The keystore password or alias could not be verified."
    }

    $gradleKeystorePath = $KeystorePath.Replace("\", "/")
    $propertyPassword = ConvertTo-JavaPropertyValue $passwordText
    $properties = @(
        "storePassword=$propertyPassword",
        "keyPassword=$propertyPassword",
        "keyAlias=$Alias",
        "storeFile=$gradleKeystorePath"
    )
    [IO.File]::WriteAllLines(
        $keyPropertiesPath,
        $properties,
        [Text.UTF8Encoding]::new($false)
    )
} finally {
    Remove-Item Env:HOOPITO_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    $propertyPassword = $null
    $passwordText = $null
}

$keystoreHash = Get-CompatibleSha256 -LiteralPath $KeystorePath
[IO.File]::WriteAllText(
    "$KeystorePath.sha256",
    "$keystoreHash  $(Split-Path -Leaf $KeystorePath)`n",
    [Text.UTF8Encoding]::new($false)
)

Write-Host "Signing configuration written to ignored file: $keyPropertiesPath"
Write-Host "Keystore SHA-256: $keystoreHash"
Write-Host "Back up the keystore in at least two encrypted offline locations before release."
