<#
.SYNOPSIS
  One-time PC setup for building the Android APK headless (Windows, PowerShell 5.1+).

.DESCRIPTION
  1. Downloads Godot 4.4.1 (win64 zip) to $GodotDir
  2. Downloads the export templates and extracts ONLY the Android files
     into %APPDATA%\Godot\export_templates\4.4.1.stable
  3. Finds the Android SDK + JDK that Flutter already uses and writes them
     into %APPDATA%\Godot\editor_settings-4.4.tres
  4. Fetches GUT (tests) and runs a headless import (also makes Godot generate its debug keystore)
  5. Saves the Godot path to tools\.godot_path + user env var GODOT

  Safe to re-run: finished steps are skipped.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\dev_setup.ps1
  powershell -ExecutionPolicy Bypass -File tools\dev_setup.ps1 -SdkPath D:\Android\Sdk
#>
param(
    [string]$GodotDir = "$HOME\godot\4.4.1",
    [string]$SdkPath = "",
    [string]$JavaPath = "",
    [switch]$SkipTemplates
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is 10x slower with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Version = '4.4.1'
$Tag = "$Version-stable"
$Base = "https://github.com/godotengine/godot/releases/download/$Tag"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$GodotData = Join-Path $env:APPDATA 'Godot'
$TemplatesDir = Join-Path $GodotData "export_templates\$Version.stable"
$EditorSettings = Join-Path $GodotData 'editor_settings-4.4.tres'
$GodotExe = Join-Path $GodotDir "Godot_v$($Tag)_win64_console.exe"

# Windows PowerShell 5.1 turns native stderr into terminating errors under
# ErrorActionPreference=Stop (git/adb/godot all print to stderr). Run native
# tools through this and check $LASTEXITCODE instead.
function Invoke-Native([scriptblock]$Block) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Block | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $old }
}

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# --- 1. Godot editor -------------------------------------------------------
Step "Godot $Version -> $GodotDir"
if (Test-Path $GodotExe) {
    Write-Host "already installed"
} else {
    New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
    $zip = Join-Path $env:TEMP "godot_$Tag.zip"
    Invoke-WebRequest "$Base/Godot_v$($Tag)_win64.exe.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $GodotDir -Force
    Remove-Item $zip
}
if (-not (Test-Path $GodotExe)) { throw "Godot console exe not found at $GodotExe" }
# Record the path right away so run.ps1/update.ps1 work even if a later step fails
# or this terminal never sees the new user env var.
Set-Content -Path (Join-Path $PSScriptRoot '.godot_path') -Value $GodotExe -Encoding ASCII
[Environment]::SetEnvironmentVariable('GODOT', $GodotExe, 'User')
$env:GODOT = $GodotExe
Write-Host "GODOT=$GodotExe (saved to tools\.godot_path)"

# --- 2. Android export templates ------------------------------------------
Step "Android export templates -> $TemplatesDir"
$needTemplates = -not (Test-Path (Join-Path $TemplatesDir 'android_debug.apk'))
if ($SkipTemplates) {
    Write-Host "skipped (-SkipTemplates)"
} elseif (-not $needTemplates) {
    Write-Host "already installed"
} else {
    Write-Host "downloading ~1.1 GB once (only the Android files are kept)..."
    $tpz = Join-Path $env:TEMP "godot_templates_$Tag.tpz"
    Invoke-WebRequest "$Base/Godot_v$($Tag)_export_templates.tpz" -OutFile $tpz
    New-Item -ItemType Directory -Force -Path $TemplatesDir | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($tpz)
    try {
        foreach ($e in $archive.Entries) {
            if ($e.Name -in @('android_debug.apk', 'android_release.apk', 'android_source.zip', 'version.txt')) {
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $TemplatesDir $e.Name), $true)
                Write-Host "  $($e.Name)"
            }
        }
    } finally {
        $archive.Dispose()
    }
    Remove-Item $tpz
}

# --- 3. Android SDK + JDK ---------------------------------------------------
Step "Android SDK / JDK"
if (-not $SdkPath) {
    foreach ($c in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk")) {
        if ($c -and (Test-Path (Join-Path $c 'platform-tools'))) { $SdkPath = $c; break }
    }
}
if (-not $SdkPath) { throw "Android SDK not found. Re-run with -SdkPath <path> (Flutter: 'flutter config' shows it)." }
if (-not (Test-Path (Join-Path $SdkPath 'build-tools'))) { throw "No build-tools in $SdkPath (install via Android Studio SDK Manager)." }
Write-Host "SDK : $SdkPath"

if (-not $JavaPath) {
    $cands = @($env:JAVA_HOME,
        "$env:ProgramFiles\Android\Android Studio\jbr",
        "$env:ProgramFiles\Android\Android Studio\jre")
    $cands += (Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium\jdk-17*" -ErrorAction SilentlyContinue | ForEach-Object FullName)
    $cands += (Get-ChildItem "$env:ProgramFiles\Microsoft\jdk-17*" -ErrorAction SilentlyContinue | ForEach-Object FullName)
    foreach ($c in $cands) {
        if ($c -and (Test-Path (Join-Path $c 'bin\keytool.exe'))) { $JavaPath = $c; break }
    }
}
if (-not $JavaPath) { throw "JDK 17+ not found. Re-run with -JavaPath <jdk dir> (Android Studio ships one in ...\Android Studio\jbr)." }
Write-Host "JDK : $JavaPath"
$env:JAVA_HOME = $JavaPath

# --- 4. Editor settings -----------------------------------------------------
Step "Editor settings -> $EditorSettings"
New-Item -ItemType Directory -Force -Path $GodotData | Out-Null
if (-not (Test-Path $EditorSettings)) {
    Set-Content -Path $EditorSettings -Encoding ASCII -Value "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]`n"
}
function Set-EditorSetting([string]$key, [string]$value) {
    $lines = [Collections.Generic.List[string]]([IO.File]::ReadAllLines($EditorSettings))
    $line = "$key = `"$($value -replace '\\', '/')`""
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith("$key = ")) { $idx = $i; break } }
    if ($idx -ge 0) {
        $lines[$idx] = $line
    } else {
        $res = $lines.IndexOf('[resource]')
        if ($res -lt 0) { $lines.Add('[resource]'); $res = $lines.Count - 1 }
        $lines.Insert($res + 1, $line)
    }
    [IO.File]::WriteAllLines($EditorSettings, $lines)   # UTF-8 without BOM
}
Set-EditorSetting 'export/android/android_sdk_path' $SdkPath
Set-EditorSetting 'export/android/java_sdk_path' $JavaPath
Write-Host "ok"

# --- 5. Import project (+ Godot creates its debug keystore) ----------------
Step "Headless import of the project"
Push-Location $RepoRoot
try {
    # GUT must exist before import, otherwise test/*.gd log "Could not find base class GutTest".
    if (-not (Test-Path 'addons\gut\plugin.cfg')) { & (Join-Path $PSScriptRoot 'fetch_gut.ps1') }
    Invoke-Native { & $GodotExe --headless --path . --import 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "godot --import failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}
$ks = Join-Path $GodotData 'keystores\debug.keystore'
if (Test-Path $ks) { Write-Host "debug keystore: $ks" }
else { Write-Warning "Godot did not create $ks - check java_sdk_path. update.ps1 will fail to sign." }

Write-Host "`nSetup done. Next: connect the tablet and run tools\update.ps1" -ForegroundColor Green
Write-Host "  adb pair <ip>:<pair-port>      (first time only, code from Wireless debugging)"
Write-Host "  adb connect <ip>:<port>"
Write-Host "  `$env:ADB_SERIAL = '<ip>:<port>'"
Write-Host "  powershell -ExecutionPolicy Bypass -File tools\update.ps1"
Write-Host "Play on this PC: powershell -ExecutionPolicy Bypass -File tools\run.ps1"
