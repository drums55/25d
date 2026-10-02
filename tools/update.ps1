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
  powershell -ExecutionPolicy Bypass -File tools\update.ps1 -Device 190:40011
    (wireless debugging: runs 'adb connect' first. A short '190:40011' = the
    Tailscale peer whose IP ends in .190 (else this PC's LAN prefix); a full
    IP or MagicDNS name works too. Remembered in tools\.adb_device)
  powershell -ExecutionPolicy Bypass -File tools\update.ps1 -Device 100.90.8.123:40011 -Pair 37099:123456
    (first time from this PC: Wireless debugging > "Pair device with pairing code"
    shows its own port + a 6-digit code; -Pair <that port>:<code> pairs first)
#>
param(
    [string]$Device = '',
    [string]$Pair = '',
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

. (Join-Path $PSScriptRoot 'godot_path.ps1')
$Godot = Resolve-Godot

Push-Location $RepoRoot
try {
    if (-not $NoPull) {
        Step "git pull"
        & (Join-Path $PSScriptRoot 'pull.ps1')
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
    $DeviceFile = Join-Path $PSScriptRoot '.adb_device'
    if (-not $Device -and -not $env:ADB_SERIAL -and (Test-Path $DeviceFile)) {
        $Device = (Get-Content $DeviceFile -Raw).Trim()
    }
    if ($Device) {
        if ($Device -match '^\d+:\d+$') {
            # only the last part of the IP: a Tailscale peer ending in it first
            # (tablet on the tailnet, PC anywhere), else this PC's LAN prefix
            $last = $Device.Split(':')[0]
            $port = $Device.Split(':')[1]
            $full = ''
            $ts = (Get-Command tailscale -ErrorAction SilentlyContinue).Source
            if (-not $ts -and (Test-Path "$env:ProgramFiles\Tailscale\tailscale.exe")) { $ts = "$env:ProgramFiles\Tailscale\tailscale.exe" }
            if ($ts) {
                foreach ($line in (Invoke-Native { & $ts status 2>&1 })) {
                    $ip = ($line.Trim() -split '\s+')[0]
                    if ($ip -match "^\d+\.\d+\.\d+\.$last$") { $full = $ip; Write-Host "Tailscale peer: $line"; break }
                }
            }
            if (-not $full) {
                $lan = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.)' } |
                    Select-Object -First 1
                if (-not $lan) { throw "No Tailscale peer or LAN address ending in .$last; pass the full address, e.g. -Device 100.x.y.$last`:$port" }
                $full = $lan.IPAddress.Substring(0, $lan.IPAddress.LastIndexOf('.')) + ".$last"
            }
            $Device = "$full`:$port"
        }
        $hostPart = $Device.Substring(0, $Device.LastIndexOf(':'))
        if ($Pair) {
            $pairPort = $Pair.Split(':')[0]
            $pairCode = $Pair.Split(':')[1]
            Step "adb pair $hostPart`:$pairPort"
            $out = Invoke-Native { & $adb pair "$hostPart`:$pairPort" $pairCode 2>&1 } | Out-String
            Write-Host $out.Trim()
            if ($out -notmatch 'Successfully paired') { throw "adb pair failed: the pairing port and code change every time that dialog opens" }
        }
        Step "adb connect $Device"
        $out = Invoke-Native { & $adb connect $Device 2>&1 } | Out-String
        Write-Host $out.Trim()
        if ($out -notmatch 'connected') {
            # say where it breaks: the network (Tailscale/Wi-Fi) or adb itself
            $devPort = [int]$Device.Substring($Device.LastIndexOf(':') + 1)
            $ping = Test-Connection -ComputerName $hostPart -Count 2 -Quiet -ErrorAction SilentlyContinue
            $tcp = Test-NetConnection -ComputerName $hostPart -Port $devPort -WarningAction SilentlyContinue
            Write-Host ("ping {0}: {1}   tcp port {2}: {3}" -f $hostPart, $ping, $devPort, $tcp.TcpTestSucceeded) -ForegroundColor Yellow
            if (-not $tcp.TcpTestSucceeded) {
                if (-not $ping) {
                    Write-Host "The tablet is not reachable at all: is Tailscale ON (connected) on the tablet and on this PC?" -ForegroundColor Yellow
                } else {
                    Write-Host "The tablet answers but nothing listens on that port: Wireless debugging is off or the port changed (read it again on the tablet)." -ForegroundColor Yellow
                }
            } else {
                Write-Host "The port is open but adb refused: this PC is not paired yet -> add -Pair <pairing port>:<code>." -ForegroundColor Yellow
            }
            throw "adb connect $Device failed"
        }
        Set-Content -Path $DeviceFile -Value $Device -Encoding ASCII
        $env:ADB_SERIAL = $Device
    }
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
