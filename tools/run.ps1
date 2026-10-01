<#
.SYNOPSIS
  Run the game on the PC (no export, no device).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\run.ps1            # pulls latest, imports, runs
  powershell -ExecutionPolicy Bypass -File tools\run.ps1 -NoPull
  powershell -ExecutionPolicy Bypass -File tools\run.ps1 --rendering-driver opengl3
  powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Editor
#>
param(
    [switch]$Editor,
    [switch]$NoPull,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$godot = Resolve-Godot
$root = Split-Path -Parent $PSScriptRoot
if (-not $NoPull) { & (Join-Path $PSScriptRoot 'pull.ps1') }
if (-not (Test-Path (Join-Path $root 'addons\gut\plugin.cfg'))) { & (Join-Path $PSScriptRoot 'fetch_gut.ps1') }
if ($Editor) {
    # The non-console exe sits next to the console one.
    $godot = $godot -replace '_console\.exe$', '.exe'
    $GodotArgs = @('-e') + $GodotArgs
}
$ErrorActionPreference = 'Continue'   # Godot prints warnings to stderr
# Always import first: after a git pull, new class_name scripts are unknown to
# Godot until its class cache is rebuilt ("Could not find type ..." errors).
$consoleExe = $godot -replace '(?<!_console)\.exe$', '_console.exe'
Write-Host "Importing..."
& $consoleExe --headless --path $root --import 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Warning "import exit code $LASTEXITCODE - run '$consoleExe --headless --path . --import' to see why" }
Write-Host "$godot --path $root $GodotArgs"
& $godot --path $root @GodotArgs
