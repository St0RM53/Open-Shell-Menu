# Builds Open-Shell from the checked-out repo (Open-Shell-Menu\Src),
# replicating Src\Setup\BuildBinaries.bat but for x64 + Win32 only (no ARM64),
# and skipping the localization/ADMX post-steps.
# The -Version parameter is stamped into the binaries' version resources so each
# change-set is distinguishable (4.5.001, 4.5.002, ...).
# Usage: powershell -ExecutionPolicy Bypass -File build.ps1 -Version 4.5.001
param(
    [string]$Version = "4.5.001"
)

$ErrorActionPreference = "Stop"

$repo    = Join-Path $PSScriptRoot "Open-Shell-Menu"
$srcDir  = Join-Path $repo "Src"
$logDir  = Join-Path $PSScriptRoot "build-logs"
New-Item -ItemType Directory -Force $logDir | Out-Null

# Version used for the version resources in the built binaries
$env:CS_VERSION      = $Version
$env:CS_VERSION_STR  = $Version.Replace(".", "_")
$env:CS_VERSION_ORIG = $Version

# Locate MSBuild via vswhere (installed with VS Build Tools)
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "vswhere.exe not found - is Visual Studio Build Tools installed?" }
$vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
$msbuild = Join-Path $vsPath "MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuild)) { throw "MSBuild.exe not found at $msbuild" }
Write-Output "Version: $Version"
Write-Output "Using MSBuild: $msbuild"

# Restore NuGet packages (projects use packages.config) - only needed on first build / after clean
& $msbuild (Join-Path $srcDir "OpenShell.sln") /m /t:Restore /nr:false -p:RestorePackagesConfig=true /verbosity:quiet /nologo /flp:"LogFile=$logDir\restore.log;Verbosity=normal"
if ($LASTEXITCODE -ne 0) { throw "NuGet restore failed (see $logDir\restore.log)" }

# Build the whole solution in the "Setup" configuration for x64 and Win32
foreach ($platform in @("x64", "Win32")) {
    Write-Output "`n=== Building $platform ==="
    & $msbuild (Join-Path $srcDir "OpenShell.sln") /m /t:Build /nr:false `
        /p:Configuration="Setup" /p:Platform=$platform `
        /verbosity:minimal /nologo /flp:"LogFile=$logDir\build-$platform.log;Verbosity=normal"
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $platform (see $logDir\build-$platform.log)" }
}

# List the produced binaries
Write-Output "`n=== Build succeeded. Output binaries ==="
Get-ChildItem (Join-Path $repo "build\bin") -Recurse -File |
    Where-Object { $_.Extension -in ".exe", ".dll" } |
    Select-Object @{n="File";e={$_.FullName.Replace($repo + "\build\bin\", "")}}, Length, @{n="Version";e={$_.VersionInfo.FileVersion}} |
    Format-Table -AutoSize
