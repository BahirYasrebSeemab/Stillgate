<#
.SYNOPSIS
  EMERGENCY: gives the kiosk user the normal Windows desktop back and removes all lockdown.
.DESCRIPTION
  Use this when a visitor PC is stuck (broken shell, agent not working, forgot password...).
  Run it as Administrator: from the admin account, or from Safe Mode.
  It does NOT need the agent, the network, or the manager.
    1. stops the agent service (so it can't switch the shell back)
    2. sets the kiosk user's Shell to explorer.exe
    3. removes the kiosk user's lockdown values and the Edge policies
  Afterwards restart the PC.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File emergency-restore.ps1 -KioskUser kiosk -DisableAgent
  UNTESTED(windows)
#>
param(
  [string]$KioskUser = "kiosk",
  # Also stop the agent from starting again at boot (re-enable with: Set-Service asd-agent -StartupType Automatic)
  [switch]$DisableAgent
)

$ErrorActionPreference = "Stop"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run this script as Administrator."
}

# 1. Stop the agent first, otherwise it would put the kiosk shell back
$service = Get-Service -Name "asd-agent" -ErrorAction SilentlyContinue
if ($null -ne $service) {
  Stop-Service -Name "asd-agent" -Force -ErrorAction SilentlyContinue
  if ($DisableAgent) { Set-Service -Name "asd-agent" -StartupType Disabled }
  Write-Host "Agent service stopped." -ForegroundColor Yellow
}

# 2. Find the kiosk user's SID and their registry hive
$sid = (Get-LocalUser -Name $KioskUser).SID.Value
$root = "HKU\$sid"
$mounted = $false
if (-not (Test-Path "Registry::HKEY_USERS\$sid")) {
  $profileDir = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid").ProfileImagePath
  $profileDir = [Environment]::ExpandEnvironmentVariables($profileDir)
  $root = "HKU\AsdRestore"
  & reg.exe load $root "$profileDir\NTUSER.DAT" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Could not load the kiosk user's registry ($profileDir\NTUSER.DAT)." }
  $mounted = $true
}

try {
  # 3. Normal desktop for the kiosk user
  & reg.exe add "$root\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d explorer.exe /f | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Could not set the Shell value." }
  Write-Host "Kiosk user's shell is now explorer.exe" -ForegroundColor Green

  # 4. Remove the kiosk user's lockdown values (errors ignored: some may not exist)
  $system = "$root\Software\Microsoft\Windows\CurrentVersion\Policies\System"
  foreach ($name in "DisableTaskMgr", "DisableLockWorkstation", "DisableChangePassword", "DisableRegistryTools") {
    & reg.exe delete $system /v $name /f 2>$null | Out-Null
  }
  & reg.exe delete "$root\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoLogoff /f 2>$null | Out-Null
}
finally {
  if ($mounted) {
    [GC]::Collect()   # release any handles so the hive can be unloaded
    & reg.exe unload $root | Out-Null
  }
}

# 5. Remove the Edge lockdown (affects all users of this PC)
$edge = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
& reg.exe delete "$edge\URLBlocklist" /f 2>$null | Out-Null
& reg.exe delete "$edge\URLAllowlist" /f 2>$null | Out-Null
foreach ($name in "InPrivateModeAvailability", "BrowserGuestModeEnabled", "BrowserAddProfileEnabled",
                  "DeveloperToolsAvailability", "DownloadRestrictions", "HideFirstRunExperience",
                  "StartupBoostEnabled", "BackgroundModeEnabled") {
  & reg.exe delete $edge /v $name /f 2>$null | Out-Null
}

Write-Host "Lockdown removed. Restart the PC now: shutdown /r /t 0" -ForegroundColor Green
