$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$enginePath = Join-Path $projectDir '.tools\godot\Godot_v4.6-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) {
    throw 'Godot 4.6 was not found in .tools\godot.'
}
Start-Process -FilePath $enginePath -ArgumentList @('--path', ('"' + $projectDir + '"')) -WorkingDirectory $projectDir
