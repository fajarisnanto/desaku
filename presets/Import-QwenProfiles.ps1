# Run with Desaku closed. Installs only the four bundled AI resident profiles.
$ErrorActionPreference = 'Stop'
if (Get-Process -Name 'AI Village' -ErrorAction SilentlyContinue) {
    throw 'Close Desaku before importing profiles so it can reload them at startup.'
}
$profiles = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'qwen-residents.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$roles = @('Creative', 'Research', 'Operation', 'Maintenance')
foreach ($role in $roles) {
    if (-not $profiles.PSObject.Properties[$role] -or $profiles.$role.model -ne 'qwen3:8b') { throw "Invalid bundled profile: $role" }
}
$folder = Join-Path $env:APPDATA 'Godot\app_userdata\AI Village — Fountain Commons'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$destination = Join-Path $folder 'residents.json'
$saved = [pscustomobject]@{}
if (Test-Path -LiteralPath $destination) {
    $saved = Get-Content -LiteralPath $destination -Raw -Encoding UTF8 | ConvertFrom-Json
    Copy-Item -LiteralPath $destination -Destination ($destination + '.backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
foreach ($role in $roles) { $saved | Add-Member -NotePropertyName $role -NotePropertyValue $profiles.$role -Force }
$json = $saved | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($destination, $json, [Text.UTF8Encoding]::new($false))
Write-Host 'Four Qwen profiles imported. Keep Ollama running with qwen3:8b installed, then open Desaku. Governor remains human.'
