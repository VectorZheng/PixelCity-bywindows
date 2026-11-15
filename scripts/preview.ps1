$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $projectDir '.tools\godot\Godot_v4.6-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Godot 4.6 executable not found.' }
Start-Process -FilePath $enginePath -ArgumentList @('--path', ('"' + $projectDir + '"')) -WorkingDirectory $projectDir
