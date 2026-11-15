$ErrorActionPreference = 'Stop'
$hostScript = Join-Path $PSScriptRoot 'scripts\desktop-host.ps1'
& $hostScript
