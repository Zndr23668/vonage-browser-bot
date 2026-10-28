# First-run setup is saved locally; this file is not uploaded anywhere.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host "Node.js is not installed. Install the LTS version from https://nodejs.org, then run this file again." -ForegroundColor Yellow
  Read-Host "Press Enter to close"
  exit 1
}

$settingsPath = Join-Path $PSScriptRoot "local-settings.json"
$configPath = Join-Path $PSScriptRoot "extension\config.local.js"

if (-not (Test-Path $settingsPath)) {
  Write-Host "One-time setup for this PC" -ForegroundColor Cyan
  $employeeId = Read-Host "Enter a short employee ID (example: employee-001)"
  if ([string]::IsNullOrWhiteSpace($employeeId) -or $employeeId.Trim() -notmatch '^[A-Za-z0-9._-]{1,64}$') {
    Write-Host "Employee ID is required and may contain only letters, numbers, dots, underscores, and hyphens (max 64 characters)." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
  }
  $settings = @{
    employeeId = $employeeId.Trim()
    token = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  }
  $settings | ConvertTo-Json | Set-Content -Encoding UTF8 $settingsPath
}

try {
  $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} catch {
  Write-Host "local-settings.json is invalid. Back it up and correct or recreate the local setup." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

if ([string]::IsNullOrWhiteSpace([string]$settings.employeeId) -or
    [string]$settings.employeeId -notmatch '^[A-Za-z0-9._-]{1,64}$' -or
    [string]$settings.token -notmatch '^.{24,}$') {
  Write-Host "local-settings.json is missing a valid employee ID or token. No agent started." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

# Regenerate the extension config on every launch to prevent stale ID/token mismatches.
$employeeIdJson = ConvertTo-Json -InputObject ([string]$settings.employeeId) -Compress
$tokenJson = ConvertTo-Json -InputObject ([string]$settings.token) -Compress
$config = @"
// Automatically generated for this PC. Keep this file private.
globalThis.RP_AGENT_CONFIG = {
  baseUrl: "http://127.0.0.1:8765",
  employeeId: $employeeIdJson,
  token: $tokenJson,
  pollMs: 3000
};
"@
Set-Content -Path $configPath -Value $config -Encoding UTF8

$env:RP_AGENT_TOKEN = [string]$settings.token
$env:RP_EMPLOYEE_ID = [string]$settings.employeeId
$env:RP_AGENT_PORT = "8765"

Write-Host ""
Write-Host "Redfin Agent is starting for employee: $($settings.employeeId)" -ForegroundColor Green
Write-Host "Keep this window open while testing. Health check: http://127.0.0.1:8765/health"
Write-Host "Stop the agent by closing this window."
Write-Host ""
node ".\agent\server.mjs"
Read-Host "Agent stopped. Press Enter to close"
