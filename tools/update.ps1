<#
.SYNOPSIS
  Normal dev loop on the PC: git pull -> headless APK export -> adb install -> launch.

.DESCRIPTION
  Needs tools\dev_setup.ps1 to have run once. Device selection: $env:ADB_SERIAL
  (e.g. '192.168.1.50:41234' after 'adb connect'); if unset, adb uses the only
  connected device.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\update.ps1
  powershell -ExecutionPolicy Bypass -File tools\update.ps1 -Log        # tail game logs after launch
  powershell -ExecutionPolicy Bypass -File tools\update.ps1 -NoPull -NoInstall
#>
param(
    [switch]$NoPull,
    [switch]$NoInstall,
    [switch]$Log
)

$ErrorActionPreference = 'Stop'
$Package = 'com.drums55.game25d'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Apk = Join-Path $RepoRoot 'build\game25d.apk'

# Windows PowerShell 5.1 turns native stderr into terminating errors under
# ErrorActionPreference=Stop (git/adb/godot all print to stderr). Run native
# tools through this and check $LASTEXITCODE instead.
function Invoke-Native([scriptblock]$Block) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Block | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $old }
}

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

$Godot = $env:GODOT
if (-not $Godot) { $Godot = [Environment]::GetEnvironmentVariable('GODOT', 'User') }
if (-not $Godot) { $Godot = "$HOME\godot\4.4.1\Godot_v4.4.1-stable_win64_console.exe" }
if (-not (Test-Path $Godot)) { throw "Godot not found ($Godot). Run tools\dev_setup.ps1 first." }

Push-Location $RepoRoot
try {
    if (-not $NoPull) {
        Step "git pull"
        Invoke-Native { git pull --ff-only 2>&1 }
        if ($LASTEXITCODE -ne 0) { throw "git pull failed" }
    }
    Invoke-Native { git log -1 --format='%h %s' }

    Step "Import (headless)"
    if (-not (Test-Path 'addons\gut\plugin.cfg')) { & (Join-Path $PSScriptRoot 'fetch_gut.ps1') }
    Invoke-Native { & $Godot --headless --path . --import 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "godot --import failed ($LASTEXITCODE)" }

    Step "Export debug APK"
    New-Item -ItemType Directory -Force -Path (Split-Path $Apk) | Out-Null
    if (Test-Path $Apk) { Remove-Item $Apk }
    Invoke-Native { & $Godot --headless --path . --export-debug 'Android' $Apk 2>&1 }
    # Godot can exit 0 on a failed export; the APK file is the real signal.
    if (-not (Test-Path $Apk)) { throw "Export failed: no APK. Read the Godot output above." }
    Write-Host ("APK: {0} ({1:N1} MB)" -f $Apk, ((Get-Item $Apk).Length / 1MB))

    if ($NoInstall) { return }

    $adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
    if (-not $adb) {
        foreach ($c in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk")) {
            if ($c -and (Test-Path "$c\platform-tools\adb.exe")) { $adb = "$c\platform-tools\adb.exe"; break }
        }
    }
    if (-not $adb) { throw "adb not found (add platform-tools to PATH)." }
    $dev = @()
    if ($env:ADB_SERIAL) { $dev = @('-s', $env:ADB_SERIAL) }

    Step "adb install $(if ($env:ADB_SERIAL) { $env:ADB_SERIAL } else { '(default device)' })"
    $out = Invoke-Native { & $adb @dev install -r $Apk 2>&1 } | Out-String
    Write-Host $out.Trim()
    if ($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
        Write-Warning "Installed app was signed with another key (e.g. other PC). Uninstalling - this wipes the save."
        Invoke-Native { & $adb @dev uninstall $Package 2>&1 } | Out-Null
        $out = Invoke-Native { & $adb @dev install $Apk 2>&1 } | Out-String
        Write-Host $out.Trim()
    }
    if ($out -notmatch 'Success') { throw "adb install failed (is the device connected? 'adb devices')" }

    Step "Launch"
    if ($Log) { Invoke-Native { & $adb @dev logcat -c 2>&1 } | Out-Null }
    Invoke-Native { & $adb @dev shell monkey -p $Package -c android.intent.category.LAUNCHER 1 2>&1 } | Out-Null
    if ($Log) {
        Write-Host "logcat (Ctrl+C to stop)..."
        Invoke-Native { & $adb @dev logcat -s godot:V 2>&1 }
    }
} finally {
    Pop-Location
}
