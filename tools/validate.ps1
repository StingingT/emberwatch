param([string]$GodotPath, [switch]$Capture)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$enginePath = Resolve-EmberwatchGodot -GodotPath $GodotPath
$projectPath = Split-Path -Parent $PSScriptRoot
$artifactPath = Join-Path $projectPath 'artifacts'
New-Item -ItemType Directory -Path $artifactPath -Force | Out-Null
Set-Content -LiteralPath (Join-Path $artifactPath '.gdignore') -Value '' -NoNewline

function Invoke-EngineCheck {
    param([string]$Name, [string[]]$EngineArguments, [string]$Expected)
    $output = @(& $enginePath --path $projectPath @EngineArguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = $output -join "`n"
    $text | Set-Content -LiteralPath (Join-Path $artifactPath "$Name.log") -Encoding utf8
    if ($exitCode -ne 0 -or $text -match 'SCRIPT ERROR:|(?m)^ERROR:|ObjectDB instances were leaked|FAIL:') {
        Write-Output $text
        throw "$Name failed (exit $exitCode)."
    }
    if ($Expected -and $text -notmatch $Expected) {
        Write-Output $text
        throw "$Name did not reach its success marker."
    }
    Write-Output "$Name passed"
}

Invoke-EngineCheck -Name 'import' -EngineArguments @('--headless', '--editor', '--import', '--quit')
Invoke-EngineCheck -Name 'economy' -EngineArguments @('--headless', '--script', 'tests/check_economy.gd', '--fixed-fps', '60', '--quit-after', '4000') -Expected 'ECONOMY_CHECKS_PASS'
Invoke-EngineCheck -Name 'combat' -EngineArguments @('--headless', '--script', 'tests/check_combat.gd', '--fixed-fps', '60', '--quit-after', '4000') -Expected 'COMBAT CHECKS PASSED:'
Invoke-EngineCheck -Name 'ui' -EngineArguments @('--headless', '--script', 'tests/check_ui.gd', '--fixed-fps', '60', '--quit-after', '4000') -Expected 'UI_CHECKS: 101 checks, 0 failures'
Invoke-EngineCheck -Name 'feedback' -EngineArguments @('--headless', '--script', 'tests/check_feedback.gd', '--fixed-fps', '60', '--quit-after', '4000') -Expected 'FEEDBACK_CHECKS_PASS:'
Invoke-EngineCheck -Name 'profile' -EngineArguments @('--headless', '--script', 'tests/check_profile.gd', '--fixed-fps', '60', '--quit-after', '4000') -Expected 'PROFILE_CHECKS_PASS:'
Invoke-EngineCheck -Name 'campaign' -EngineArguments @('--headless', '--script', 'tests/check_campaign.gd', '--fixed-fps', '60', '--quit-after', '4000') -Expected 'CAMPAIGN_CHECKS_PASS'
Invoke-EngineCheck -Name 'playthrough' -EngineArguments @('--headless', '--script', 'tests/check_playthrough.gd', '--fixed-fps', '60', '--quit-after', '120000') -Expected 'PLAYTHROUGH PASSED:'
Invoke-EngineCheck -Name 'campaign_playthrough' -EngineArguments @('--headless', '--script', 'tests/check_campaign_playthrough.gd', '--fixed-fps', '60', '--quit-after', '150000') -Expected 'CAMPAIGN_PLAYTHROUGH_PASS:'
if ($Capture) {
    Invoke-EngineCheck -Name 'capture' -EngineArguments @('--script', 'tools/capture_game.gd', '--fixed-fps', '60', '--quit-after', '1000') -Expected 'CAPTURE_PASS'
    Invoke-EngineCheck -Name 'progression' -EngineArguments @('--script', 'tools/capture_progression.gd', '--fixed-fps', '60', '--quit-after', '600') -Expected 'PROGRESSION_CAPTURE_PASS'
    Invoke-EngineCheck -Name 'campaign_capture' -EngineArguments @('--script', 'tools/capture_campaign.gd', '--fixed-fps', '60', '--quit-after', '1200') -Expected 'CAMPAIGN_CAPTURE_PASS'
    Invoke-EngineCheck -Name 'ui_capture' -EngineArguments @('--script', 'tests/check_ui.gd', '--fixed-fps', '60', '--quit-after', '4000', '--', '--capture-ui') -Expected 'UI_CHECKS: 101 checks, 0 failures'
}
