# First-run setup is saved locally; this file is not uploaded anywhere.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$bundledNode = Join-Path $PSScriptRoot "runtime\node-v24.22.1-win-x64\node.exe"
if (Test-Path $bundledNode) {
  $nodeExe = $bundledNode
} elseif (Get-Command node -ErrorAction SilentlyContinue) {
  $nodeExe = (Get-Command node).Source
} else {
  Write-Host "Node.js runtime is missing. Run Install-Redfin-Agent.cmd from the extracted installer package." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

$settingsPath = Join-Path $PSScriptRoot "local-settings.json"
$configPath = Join-Path $PSScriptRoot "extension\config.local.js"

if (-not (Test-Path $settingsPath)) {
  Write-Host "One-time setup for this computer" -ForegroundColor Cyan
  $employeeId = Read-Host "Enter the assigned employee ID (example: employee-001)"
  if ([string]::IsNullOrWhiteSpace($employeeId) -or $employeeId.Trim() -notmatch '^[A-Za-z0-9._-]{1,64}$') {
    Write-Host "Employee ID is required and may contain only letters, numbers, dots, underscores, and hyphens (max 64 characters)." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
  }
  $settings = @{
    employeeId = $employeeId.Trim()
    token = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
    makeWebhookUrl = ""
  }
  $settings | ConvertTo-Json | Set-Content -Encoding UTF8 $settingsPath
}

try { $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json }
catch { Write-Host "local-settings.json is invalid. No agent started." -ForegroundColor Red; Read-Host "Press Enter to close"; exit 1 }

if ([string]::IsNullOrWhiteSpace([string]$settings.employeeId) -or
    [string]$settings.employeeId -notmatch '^[A-Za-z0-9._-]{1,64}$' -or
    [string]$settings.token -notmatch '^.{24,}$') {
  Write-Host "Local settings do not contain a valid employee ID and token. No agent started." -ForegroundColor Red
  Read-Host "Press Enter to close"
  exit 1
}

if ([string]::IsNullOrWhiteSpace([string]$settings.makeWebhookUrl)) {
  Write-Host ""
  Write-Host "Remote test connection" -ForegroundColor Cyan
  Write-Host "Copy the webhook URL from your existing Make scenario: Vonage Browser Results."
  $makeWebhookUrl = Read-Host "Paste the Make webhook URL (leave blank for local-only mode)"
  if (-not [string]::IsNullOrWhiteSpace($makeWebhookUrl)) {
    try {
      $makeUri = [Uri]$makeWebhookUrl.Trim()
      if ($makeUri.Scheme -ne "https" -or $makeUri.Host -notmatch '^hook\.[a-z0-9-]+\.make\.com$' -or
          $makeUri.Query -or $makeUri.Fragment -or $makeUri.AbsolutePath -notmatch '^/[A-Za-z0-9_-]{20,}$') {
        throw "URL format is not an HTTPS Make webhook URL."
      }
      $settings.makeWebhookUrl = $makeUri.AbsoluteUri.TrimEnd("/")
      $settings | ConvertTo-Json | Set-Content -Encoding UTF8 $settingsPath
    } catch {
      Write-Host "Invalid Make webhook URL. No agent started: $($_.Exception.Message)" -ForegroundColor Red
      Read-Host "Press Enter to close"
      exit 1
    }
  } else {
    $settings.makeWebhookUrl = ""
    $settings | ConvertTo-Json | Set-Content -Encoding UTF8 $settingsPath
  }
}

# Refresh extension config on each launch so local settings and extension credentials cannot drift.
$employeeIdJson = ConvertTo-Json -InputObject ([string]$settings.employeeId) -Compress
$tokenJson = ConvertTo-Json -InputObject ([string]$settings.token) -Compress
$config = @"
// Automatically generated for this computer. Keep this file private.
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
$env:RP_MAKE_WEBHOOK_URL = [string]$settings.makeWebhookUrl

Write-Host ""
Write-Host "Redfin Agent is starting for employee: $($settings.employeeId)" -ForegroundColor Green
Write-Host "Keep this window open while testing. Health check: http://127.0.0.1:8765/health"
if ($env:RP_MAKE_WEBHOOK_URL) {
  Write-Host "Make remote test mode: one test-only URL, up to five minutes."
} else {
  Write-Host "No Make URL configured; running local-only mode."
}
Write-Host "Stop the agent by closing this window."
Write-Host ""
& $nodeExe ".\agent\server.mjs"
Read-Host "Agent stopped. Press Enter to close"
