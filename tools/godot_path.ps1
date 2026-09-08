function Resolve-EmberwatchGodot {
    param([string]$GodotPath)
    $candidates = @($GodotPath, $env:GODOT_BIN)
    $found = Get-Command godot, godot4 -ErrorAction SilentlyContinue
    $candidates += @($found | ForEach-Object { $_.Source })
    $candidates += Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7-stable_win64_console.exe'
    $candidates += Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7-stable_win64.exe'
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $version = (& $candidate --version | Out-String).Trim()
            if ($version -notlike '4.7.stable*') {
                throw "Emberwatch is pinned to Godot 4.7 stable. Found: $version at $candidate"
            }
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw 'Godot 4.7 stable was not found. Pass -GodotPath to the launcher or set GODOT_BIN.'
}
