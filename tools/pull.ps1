<#
.SYNOPSIS
  git pull that cannot be blocked by Godot-generated *.import files.

.DESCRIPTION
  Godot writes <asset>.import next to every imported asset. When the repo
  later commits that same file, "git pull" refuses to overwrite the local
  untracked copy. Those files are regenerated on the next import, so this
  deletes untracked *.import files first, then fast-forwards.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $untracked = @(git ls-files --others --exclude-standard -- '*.import' 2>$null)
    $ErrorActionPreference = $old
    foreach ($f in $untracked) {
        if ($f -and (Test-Path $f)) {
            Remove-Item -LiteralPath $f -Force
            Write-Host "removed untracked $f"
        }
    }
    $ErrorActionPreference = 'Continue'
    git pull --ff-only 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0) { throw "git pull failed ($code)" }
} finally {
    Pop-Location
}
