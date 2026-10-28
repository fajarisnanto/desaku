param([string]$GodotPath = 'Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    & $GodotPath --headless --path . --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    & $GodotPath --headless --path . -- --self-test
    if ($LASTEXITCODE -ne 0) { throw 'Navigation test failed.' }
    & $GodotPath --headless --path . -- --social-test
    if ($LASTEXITCODE -ne 0) { throw 'Social test failed.' }
    New-Item -ItemType Directory -Force build | Out-Null
    & $GodotPath --headless --path . --export-release 'Windows Desktop' 'build/AI Village.exe'
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
} finally {
    Pop-Location
}
