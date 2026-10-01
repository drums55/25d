<#
.SYNOPSIS
  Run the game on the PC (no export, no device).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\run.ps1
  powershell -ExecutionPolicy Bypass -File tools\run.ps1 --rendering-driver opengl3
  powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Editor
#>
param(
    [switch]$Editor,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$godot = Resolve-Godot
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'addons\gut\plugin.cfg'))) { & (Join-Path $PSScriptRoot 'fetch_gut.ps1') }
if ($Editor) {
    # The non-console exe sits next to the console one.
    $godot = $godot -replace '_console\.exe$', '.exe'
    $GodotArgs = @('-e') + $GodotArgs
}
Write-Host "$godot --path $root $GodotArgs"
$ErrorActionPreference = 'Continue'   # Godot prints warnings to stderr
& $godot --path $root @GodotArgs
