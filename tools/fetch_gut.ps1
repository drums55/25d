# Fetch GUT (unit tests) at the pinned tag into addons\gut (gitignored). Optional on the PC.
$ErrorActionPreference = 'Stop'
$Tag = 'v9.4.0'
$Root = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path $env:TEMP "gut_$Tag"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
$ErrorActionPreference = 'Continue'   # git prints progress to stderr
git -c advice.detachedHead=false clone -q --depth 1 --branch $Tag https://github.com/bitwes/Gut $tmp 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) { throw "git clone failed" }
$dst = Join-Path $Root 'addons\gut'
if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
New-Item -ItemType Directory -Force -Path (Join-Path $Root 'addons') | Out-Null
Copy-Item -Recurse (Join-Path $tmp 'addons\gut') $dst
Remove-Item -Recurse -Force $tmp
Write-Host "GUT $Tag -> $dst"
