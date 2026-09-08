param([string]$OutputPath)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $projectPath 'builds\emberwatch-source.zip'
}
$outputDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($OutputPath))
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
Set-Content -LiteralPath (Join-Path $outputDirectory '.gdignore') -Value '' -NoNewline
$names = @('.gitattributes', '.gitignore', '.godot-version', 'project.godot',
    'export_presets.cfg', 'play_windows.cmd', 'README.md', 'PROJECT_PLAN.md',
    'common', 'docs', 'entities', 'game', 'levels', 'tests', 'tools', 'ui')
$inputs = @($names | ForEach-Object { Join-Path $projectPath $_ })
Compress-Archive -LiteralPath $inputs -DestinationPath $OutputPath -Force
Get-Item -LiteralPath $OutputPath | Select-Object FullName, Length
$sourceHash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
Write-Output "SHA256: $sourceHash"
