<#
.SYNOPSIS
  Installs the Stillgate agent service and kiosk shell on ONE visitor PC.
.DESCRIPTION
  Run as Administrator on the visitor PC. Before running:
    - Node.js LTS is installed (default path below)
    - the kiosk user exists (standard user, NOT an administrator)
    - you have: the agent bundle folder (main.js + cli.js from `bun run bundle`),
      the built kiosk shell folder (from `bun run dist` in packages/kiosk-shell),
      and WinSW-x64.exe (downloaded yourself, see tools/service-wrapper/README.md)
  What it does:
    1. copies the agent and kiosk shell into C:\Program Files\Stillgate
    2. creates C:\ProgramData\Stillgate with strict permissions
    3. installs and starts the service
    4. tells the agent who the kiosk user is
  It does NOT change the kiosk user's shell: the agent does that itself, and only after you
  turn dry-run off. The safe defaults stay on: dryRun = true, enforcement = audit.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File install-agent.ps1 -KioskUser kiosk `
    -AgentSource D:\release\agent -KioskShellSource D:\release\win-unpacked -WinSWExe D:\WinSW-x64.exe
  UNTESTED(windows)
#>
param(
  [string]$KioskUser = "kiosk",
  [Parameter(Mandatory)] [string]$AgentSource,
  [Parameter(Mandatory)] [string]$KioskShellSource,
  [Parameter(Mandatory)] [string]$WinSWExe,
  [string]$NodeExe = "C:\Program Files\nodejs\node.exe"
)

$ErrorActionPreference = "Stop"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run this script as Administrator."
}
foreach ($path in $NodeExe, "$AgentSource\main.js", "$AgentSource\cli.js", "$KioskShellSource\kiosk-shell.exe", $WinSWExe) {
  if (-not (Test-Path $path)) { throw "Not found: $path" }
}

# The kiosk user must exist and must NOT be an administrator
$user = Get-LocalUser -Name $KioskUser
$sid = $user.SID.Value
# (Get-LocalGroupMember can fail on PCs whose Administrators group contains unresolvable accounts)
try {
  $admins = Get-LocalGroupMember -SID "S-1-5-32-544" -ErrorAction Stop | ForEach-Object { $_.SID.Value }
  if ($admins -contains $sid) { throw "$KioskUser is an administrator. The kiosk user must be a standard user." }
} catch [Microsoft.PowerShell.Commands.GroupMemberNotFoundException] {
} catch {
  if ($_.Exception.Message -like "*must be a standard user*") { throw }
  Write-Warning "Could not list the Administrators group. CHECK BY HAND that '$KioskUser' is a standard user."
}

$programDir = "C:\Program Files\Stillgate"
$agentDir = "$programDir\agent"
$kioskDir = "$programDir\kiosk-shell"
$toolsDir = "$programDir\tools"
$dataDir = "C:\ProgramData\Stillgate"
$shellDir = "$dataDir\shell"

# 1. Program files
New-Item -ItemType Directory -Force -Path $agentDir, $kioskDir, $toolsDir | Out-Null
Copy-Item "$PSScriptRoot\emergency-restore.ps1" -Destination $toolsDir -Force   # for docs/RECOVERY.md
Copy-Item "$AgentSource\main.js", "$AgentSource\cli.js" -Destination $agentDir -Force
Copy-Item "$KioskShellSource\*" -Destination $kioskDir -Recurse -Force
Copy-Item $WinSWExe -Destination "$agentDir\stillgate-agent.exe" -Force
(Get-Content "$PSScriptRoot\..\service-wrapper\stillgate-agent.xml" -Raw).Replace("__NODE_EXE__", $NodeExe) |
  Set-Content -Path "$agentDir\stillgate-agent.xml" -Encoding UTF8

# 2. Data folder: only SYSTEM (S-1-5-18) and Administrators (S-1-5-32-544).
#    SIDs are used instead of names, so this also works on Russian/Tajik Windows.
#    icacls:  /inheritance:r = drop inherited permissions   /grant:r = replace with exactly these
#             (OI)(CI) = also applies to files and subfolders   F = full control   RX = read
New-Item -ItemType Directory -Force -Path $dataDir, $shellDir | Out-Null
& icacls.exe $dataDir /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" | Out-Null
# The shell subfolder (token file) is ALSO readable by the kiosk user
& icacls.exe $shellDir /grant "*${sid}:(OI)(CI)RX" | Out-Null

# 3. Service
& "$agentDir\stillgate-agent.exe" install
& "$agentDir\stillgate-agent.exe" start

# 4. Tell the agent who the kiosk user is
& $NodeExe "$agentDir\cli.js" init --kiosk-user $KioskUser --kiosk-sid $sid --shell-exe "$kioskDir\kiosk-shell.exe"

Write-Host ""
Write-Host "Installed. Safe defaults are ON: dry-run (nothing changes) and audit (nothing is closed)." -ForegroundColor Green
Write-Host "Next steps:"
Write-Host "  1. Pair:    & '$NodeExe' '$agentDir\cli.js' pair `"<pairing string from the manager>`""
Write-Host "  2. Check:   & '$NodeExe' '$agentDir\cli.js' status"
Write-Host "  3. Read the log in $dataDir\logs\agent.log, follow TESTING.md before turning dry-run off."
