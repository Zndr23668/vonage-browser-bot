param([int]$WaitSeconds = 0, [switch]$QueueSafeTest)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$settingsPath = Join-Path $root "local-settings.json"
$configPath = Join-Path $root "extension\config.local.js"
$deadline = (Get-Date).AddSeconds([Math]::Max(0,$WaitSeconds))
$health = $null
do {
  try { $health = Invoke-RestMethod -Uri "http://127.0.0.1:8765/health" -TimeoutSec 3; break } catch {
    if ((Get-Date) -ge $deadline) { break }
    Start-Sleep -Seconds 2
  }
} while ((Get-Date) -lt $deadline)
Write-Host "Remote Professional Windows Local Agent diagnostics" -ForegroundColor Cyan
if (!(Test-Path $settingsPath) -or !(Test-Path $configPath)) { Write-Host "[FAIL] Local settings or Chrome extension config is missing. Run installer." -ForegroundColor Red; exit 1 }
try { $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json } catch { Write-Host "[FAIL] Local settings cannot be parsed." -ForegroundColor Red; exit 1 }
if ([string]$settings.employeeId -notmatch '^[A-Za-z0-9._-]{1,64}$' -or [string]$settings.token -notmatch '^.{24,}$') { Write-Host "[FAIL] Employee ID or local token is invalid." -ForegroundColor Red; exit 1 }
Write-Host "[PASS] Local settings and device token exist."
if (!$health) { Write-Host "[FAIL] Agent health endpoint did not respond on port 8765." -ForegroundColor Red; exit 1 }
if ($health.status -ne "ok" -or $health.employeeId -ne $settings.employeeId) { Write-Host "[FAIL] Agent status or employee ID does not match local settings." -ForegroundColor Red; exit 1 }
Write-Host "[PASS] Local agent health endpoint responds for the configured employee."
Write-Host ("[INFO] Make configured: " + [bool]$health.remoteMakeConfigured)
Write-Host ("[INFO] Bounded remote polling active: " + [bool]$health.remotePolling)
$chromePaths = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",([Environment]::GetEnvironmentVariable("ProgramFiles(x86)")+"\Google\Chrome\Application\chrome.exe"),"$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
if ($chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1) { Write-Host "[PASS] Chrome executable found; confirm extension is enabled at chrome://extensions." } else { Write-Host "[WARN] Chrome was not found in standard locations." -ForegroundColor Yellow }
if ($QueueSafeTest) {
  $payload = @{employeeId=[string]$settings.employeeId;url="https://www.redfin.com/";testOnly=$true} | ConvertTo-Json -Compress
  try {
    $result = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:8765/jobs" -Headers @{Authorization=("Bearer "+[string]$settings.token)} -ContentType "application/json" -Body $payload
    if (!$result.accepted -or $result.testOnly -ne $true) { throw "Agent did not accept a test-only job." }
    Write-Host "[PASS] Safe Redfin homepage dry-run queued with testOnly=true. No lead action is authorized."
  } catch { Write-Host ("[FAIL] Safe test could not be queued: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
}
Write-Host "Diagnostics complete. This does not prove Chrome-to-Make end-to-end connectivity."
