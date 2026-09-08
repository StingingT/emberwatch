param([string]$GodotPath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-EmberwatchGodot -GodotPath $GodotPath
$projectPath = Split-Path -Parent $PSScriptRoot
& $enginePath --path $projectPath
exit $LASTEXITCODE
