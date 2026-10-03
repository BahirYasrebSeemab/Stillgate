<#
.SYNOPSIS
  READ-ONLY readiness check for a visitor PC (or the manager PC). Changes nothing.
.DESCRIPTION
  Run in PowerShell (as Administrator for the full picture). Prints OK / WARN / FAIL lines.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File check-pc.ps1 -KioskUser kiosk -ManagerIP 192.168.1.10
#>
param(
  [string]$KioskUser = "kiosk",
  [string]$ManagerIP = "",
  [int]$ManagerPort = 47800,
  [string]$NodeExe = "C:\Program Files\nodejs\node.exe"
)

function Report([string]$Level, [string]$Text) {
  $color = @{ OK = "Green"; WARN = "Yellow"; FAIL = "Red"; INFO = "Gray" }[$Level]
  Write-Host ("[{0,-4}] {1}" -f $Level, $Text) -ForegroundColor $color
}

$os = Get-CimInstance Win32_OperatingSystem
Report INFO "Windows: $($os.Caption) build $($os.BuildNumber), PC name $env:COMPUTERNAME"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Report OK "running as Administrator" }
else { Report WARN "not running as Administrator (install-agent.ps1 needs it)" }

if (Test-Path $NodeExe) { Report OK ("Node.js found: " + (& $NodeExe -v)) }
else { Report FAIL "Node.js not found at $NodeExe (install Node.js LTS)" }

$user = Get-LocalUser -Name $KioskUser -ErrorAction SilentlyContinue
if ($null -eq $user) { Report FAIL "kiosk user '$KioskUser' does not exist" }
else {
  Report OK "kiosk user '$KioskUser' exists (SID $($user.SID.Value)), enabled: $($user.Enabled)"
  if ($KioskUser -notmatch '^[A-Za-z0-9._ -]{1,20}$') { Report FAIL "kiosk user name must use English letters/digits only" }
  try {
    $admins = Get-LocalGroupMember -SID "S-1-5-32-544" -ErrorAction Stop | ForEach-Object { $_.SID.Value }
    if ($admins -contains $user.SID.Value) { Report FAIL "'$KioskUser' is an ADMINISTRATOR; it must be a standard user" }
    else { Report OK "'$KioskUser' is not an administrator" }
  } catch { Report WARN "could not list Administrators; check by hand that '$KioskUser' is a standard user" }
  $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$($user.SID.Value)"
  if (Test-Path $profileKey) { Report OK "kiosk user profile exists (they have signed in once)" }
  else { Report WARN "kiosk user has never signed in: sign in as '$KioskUser' once, then sign out" }
}

$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (Test-Path $edge) { Report OK "Microsoft Edge found" } else { Report FAIL "Edge not found at $edge" }

$service = Get-Service -Name "asd-agent" -ErrorAction SilentlyContinue
if ($null -eq $service) { Report INFO "agent service not installed yet" }
else { Report INFO "agent service: $($service.Status)" }

Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
  ForEach-Object { Report INFO "this PC's address: $($_.IPAddress) ($($_.InterfaceAlias))" }

if ($ManagerIP -ne "") {
  $reach = Test-NetConnection -ComputerName $ManagerIP -Port $ManagerPort -WarningAction SilentlyContinue
  if ($reach.TcpTestSucceeded) { Report OK "manager reachable at ${ManagerIP}:$ManagerPort" }
  else { Report FAIL "cannot reach the manager at ${ManagerIP}:$ManagerPort (manager running? firewall rule on the manager PC?)" }
}
