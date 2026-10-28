@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Redfin-Agent.ps1"
if errorlevel 1 (
  echo.
  echo Installation did not complete. Read the error above and run this file again.
  pause
)