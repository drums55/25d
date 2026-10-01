# Dot-source this: . "$PSScriptRoot\godot_path.ps1"; $godot = Resolve-Godot
# Finds the Godot console exe without relying on the GODOT env var being
# visible in this terminal (VS Code / old windows do not see new user env vars).
# Order: tools\.godot_path (written by dev_setup.ps1) -> $env:GODOT ->
# user env GODOT -> <repo parent>\godot\4.4.1 -> %USERPROFILE%\godot\4.4.1
function Resolve-Godot {
    $exeName = 'Godot_v4.4.1-stable_win64_console.exe'
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $cands = @()
    $pathFile = Join-Path $PSScriptRoot '.godot_path'
    if (Test-Path $pathFile) { $cands += (Get-Content $pathFile -TotalCount 1).Trim() }
    $cands += $env:GODOT
    $cands += [Environment]::GetEnvironmentVariable('GODOT', 'User')
    $cands += (Join-Path (Split-Path -Parent $repoRoot) "godot\4.4.1\$exeName")
    $cands += (Join-Path $HOME "godot\4.4.1\$exeName")
    foreach ($c in $cands) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    throw "Godot not found (tried: $(($cands | Where-Object { $_ }) -join '; ')). Run tools\dev_setup.ps1 first."
}
