<#
.SYNOPSIS
  On the MANAGER PC: allow the agent port only from the visitor PCs' addresses.
.DESCRIPTION
  Run as Administrator on the manager PC.
  - Creates one inbound rule: TCP 47800, allowed only from the given visitor PC addresses.
  - Removes any "allow this program" rules Windows created for the manager app
    (from the first-run firewall pop-up), because those allow ALL addresses.
  Windows Firewall blocks everything else inbound by default.
  Give the visitor PCs fixed addresses with DHCP reservations in the router.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File firewall-manager.ps1 -VisitorIPs 192.168.1.21,192.168.1.22,192.168.1.23,192.168.1.24
  UNTESTED(windows)
#>
param(
  [Parameter(Mandatory)] [string[]]$VisitorIPs,
  [int]$Port = 47800,
  [string]$ManagerExe = "C:\Program Files\Stillgate Manager\Stillgate Manager.exe"
)

$ErrorActionPreference = "Stop"
$ruleName = "Stillgate - agents"

foreach ($ip in $VisitorIPs) {
  if (-not ($ip -as [System.Net.IPAddress])) { throw "Not an IP address: $ip" }
}

# Program-wide allow rules (from the pop-up) would let any address in: remove them
Get-NetFirewallApplicationFilter -Program $ManagerExe -ErrorAction SilentlyContinue |
  Get-NetFirewallRule -ErrorAction SilentlyContinue |
  Remove-NetFirewallRule -ErrorAction SilentlyContinue

Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName $ruleName `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port `
  -RemoteAddress $VisitorIPs -Profile Any | Out-Null

Write-Host "Port $Port is now open only for: $($VisitorIPs -join ', ')" -ForegroundColor Green
Write-Host "If Windows shows a firewall pop-up for the manager app later, choose Cancel and run this again."
