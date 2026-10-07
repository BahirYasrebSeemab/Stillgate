<#
.SYNOPSIS
  Removes the Stillgate agent from a visitor PC and gives the kiosk user the normal desktop back.
.DESCRIPTION
  Run as Administrator. Restores the shell and removes lockdown first (emergency-restore.ps1),
  then removes the service. Add -RemoveFiles to also delete the program and data folders.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File uninstall-agent.ps1 -KioskUser kiosk -RemoveFiles
  UNTESTED(windows)
#>
param(
  [string]$KioskUser = "kiosk",
  [switch]$RemoveFiles
)

$ErrorActionPreference = "Stop"

& "$PSScriptRoot\emergency-restore.ps1" -KioskUser $KioskUser

$wrapper = "C:\Program Files\Stillgate\agent\stillgate-agent.exe"
if (Test-Path $wrapper) {
  & $wrapper uninstall
  Write-Host "Service removed." -ForegroundColor Green
}

if ($RemoveFiles) {
  Remove-Item "C:\Program Files\Stillgate" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item "C:\ProgramData\Stillgate" -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Program and data folders deleted (including the pairing secret)." -ForegroundColor Green
}
Write-Host "Restart the PC to finish: shutdown /r /t 0"
