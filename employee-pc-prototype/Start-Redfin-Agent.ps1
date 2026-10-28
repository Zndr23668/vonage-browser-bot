# First-run setup is saved locally; this file is not uploaded anywhere.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host "Node.js is not installed. Install the LTS version from https://nodejs.org, then double-click this file again." -ForegroundColor Yellow
  Read-Host "Press Enter to close"
  exit 1
}

$settingsPath = Join-Path $PSScriptRoot "local-settings.json"
$configPath = Join-Path $PSScriptRoot "extension\config.js"

if (-not (Test-Path $settingsPath)) {
  Write-Host "One-time setup for this PC" -ForegroundColor Cyan
  $employeeId = Read-Host "Enter a short employee ID (example: employee-001)"
  if ([string]::IsNullOrWhiteSpace($employeeId)) {
    Write-Host "Employee ID is required." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
  }
  $settings = @{
    employeeId = $employeeId.Trim()
    token = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
  }
  $settings | ConvertTo-Json | Set-Content -Encoding UTF8 $settingsPath
  $config = @"
// Automatically generated for this PC. Keep this file private.
globalThis.RP_AGENT_CONFIG = {
  baseUrl: "http://127.0.0.1:8765",
  employeeId: "$($settings.employeeId)",
  token: "$($settings.token)",
  pollMs: 3000
};
"@
  Set-Content -Path $configPath -Value $config -Encoding UTF8
  Write-Host "This PC has been configured." -ForegroundColor Green
}

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$env:RP_AGENT_TOKEN = $settings.token
$env:RP_EMPLOYEE_ID = $settings.employeeId
$env:RP_AGENT_PORT = "8765"

Write-Host ""
Write-Host "Redfin Agent is starting for employee: $($settings.employeeId)" -ForegroundColor Green
Write-Host "Keep this window open while testing. Health check: http://127.0.0.1:8765/health"
Write-Host "Stop the agent by closing this window."
Write-Host ""
node ".\agent\server.mjs"
Read-Host "Agent stopped. Press Enter to close"
