@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Redfin-Agent.ps1"
if errorlevel 1 (
  echo.
  echo The agent stopped with an error. Run Test-Redfin-Agent.ps1 for diagnostics.
  pause
)
