# Installing Stillgate (manager PC + every visitor PC)

The full installation, start to finish. Do the **manager PC first**, then the visitor PCs **one at a time**.
Finish each visitor PC (up to step V12) before starting the next one.

All commands go into **PowerShell opened as Administrator** unless a step says otherwise
(Start → type `powershell` → right-click → **Run as administrator**).

## What to bring (USB stick)
- The `stillgate-deploy` folder. If you downloaded it from GitHub, also get `kiosk-shell-<version>-win-x64.zip` and `Stillgate-Manager-Setup-<version>.exe` from the **Releases** page. Unzip the kiosk shell into `stillgate-deploy\visitor-pc\kiosk-shell\` (`kiosk-shell.exe` must be directly inside that folder).
- **Node.js LTS** installer (Windows x64 `.msi`) from https://nodejs.org
- **WinSW-x64.exe** from https://github.com/winsw/winsw/releases. Put it in `stillgate-deploy\visitor-pc\`.
- **Autologon** (Sysinternals) from https://learn.microsoft.com/sysinternals/downloads/autologon
- A piece of paper for: the manager IP, each PC's IP, the restore password, the kiosk password, the admin passwords.

## Plan the addresses first (once)
Every PC needs an address that never changes. Do it in the **router** with a *DHCP reservation* ("static lease"), one per PC:
1. On each PC, find its network card's MAC address and current IP:
   ```powershell
   ipconfig /all
   ```
   Look at the adapter you use (Ethernet or Wi-Fi): **Physical Address** = MAC (e.g. `A4-BB-6D-12-34-56`), **IPv4 Address** = IP.
2. In the router's admin page (usually `http://192.168.1.1` or `http://192.168.0.1`, see the sticker on the router), find **DHCP reservation / Address reservation / Static lease** and reserve one IP per MAC. Example plan:

   | PC | IP |
   |---|---|
   | Manager PC | `192.168.1.10` |
   | Visitor PC 1 | `192.168.1.21` |
   | Visitor PC 2 | `192.168.1.22` |
   | Visitor PC 3 | `192.168.1.23` |
   | Visitor PC 4 | `192.168.1.24` |

3. Restart each PC (or run `ipconfig /renew`) and check with `ipconfig` that it got its reserved IP.

Use **your** network's numbers below wherever you see `192.168.1.x`.

---

## Part M: Manager PC

**M1. Install the manager.** Double-click `stillgate-deploy\manager-pc\Stillgate-Manager-Setup-0.1.0.exe` → Next → Install. Start **Stillgate Manager**.
It starts automatically with Windows and keeps running in the tray (closing the window does **not** stop it).

**M2. Firewall pop-up.** If Windows asks, tick **Private networks** and click **Allow**. (Step M5 replaces this with a stricter rule.)

**M3. Set the restore password.** Tab **Restore password** → at least 10 characters → **Set password**.
This is the password for the Space + B + Y + S maintenance hotkey on every visitor PC. **Write it down and keep it safe.**

**M4. Add the allowed apps and websites.** Tab **Allowed apps & sites** → add each app (name + **Program path** of its `.exe`, e.g. `C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE`) and each website (name + address, e.g. `www.coursera.org`) → **Save and send to all computers**.
To find an app's path on a visitor PC: right-click its Start-menu shortcut → *Open file location* → right-click the shortcut → *Properties* → **Target**.

**M5. Lock the firewall to the visitor PCs** (after you know all their IPs):
```powershell
cd C:\path\to\stillgate-deploy\manager-pc\tools\scripts
powershell -ExecutionPolicy Bypass -File firewall-manager.ps1 -VisitorIPs 192.168.1.21,192.168.1.22,192.168.1.23,192.168.1.24
```
Now only those four addresses can reach the manager. If you add a PC later, run it again with the full list.

---

## Part V: Each visitor PC (repeat V1–V12 on every PC)

> **PC that already had the old test version (`AsdLabLock`)?** Remove it first, as Administrator:
> ```powershell
> powershell -ExecutionPolicy Bypass -File "C:\Program Files\AsdLabLock\tools\emergency-restore.ps1" -KioskUser kiosk -DisableAgent
> & "C:\Program Files\AsdLabLock\agent\asd-agent.exe" stop
> & "C:\Program Files\AsdLabLock\agent\asd-agent.exe" uninstall
> Remove-Item "C:\Program Files\AsdLabLock","C:\ProgramData\AsdLabLock" -Recurse -Force
> shutdown /r /t 0
> ```
> Then remove that old PC from the manager's list (**Remove**) and continue with V1 (skip V2–V3 if the `kiosk` user already exists).

**V1. Make sure you have an administrator account with a strong password.** This is your way back in if anything goes wrong. Check which accounts are admins:
```powershell
Get-LocalGroupMember -Group Administrators
```
Only management should know this password.

**V2. Create the kiosk user** (a normal, NON-admin account):
```powershell
net user kiosk "Kiosk-Pass-2026!" /add
net user kiosk /passwordchg:no
Set-LocalUser -Name kiosk -PasswordNeverExpires $true
```
- `net user kiosk "<password>" /add`: creates the account `kiosk` (new accounts are standard users, which is what we want). Choose your own password and write it down.
- `/passwordchg:no`: the kiosk user can't change its own password.
- `PasswordNeverExpires`: Windows will never ask to change it (that would break automatic sign-in).

**V3. Sign in once as `kiosk`.** Start → your account picture → *Switch user* (or sign out) → sign in as **kiosk** → wait until the desktop is fully ready → sign out → sign back in as the **administrator**.
This creates the kiosk user's profile (its registry hive), which the agent needs.

**V4. Install Node.js LTS.** Run the `.msi` with the default options. Check:
```powershell
& "C:\Program Files\nodejs\node.exe" -v
```

**V5. Copy the files.** Copy `stillgate-deploy\visitor-pc` to `C:\stillgate-install`. You should have:
`C:\stillgate-install\agent\main.js`, `C:\stillgate-install\kiosk-shell\kiosk-shell.exe`, `C:\stillgate-install\WinSW-x64.exe`, `C:\stillgate-install\tools\...`

**V6. Check the PC** (read-only, changes nothing). The manager must be running:
```powershell
cd C:\stillgate-install\tools\scripts
powershell -ExecutionPolicy Bypass -File check-pc.ps1 -KioskUser kiosk -ManagerIP 192.168.1.10
```
Every line must be `OK` or `INFO`. Fix any `FAIL` before going on.

**V7. Install the agent service and the kiosk shell:**
```powershell
powershell -ExecutionPolicy Bypass -File install-agent.ps1 -KioskUser kiosk -AgentSource C:\stillgate-install\agent -KioskShellSource C:\stillgate-install\kiosk-shell -WinSWExe C:\stillgate-install\WinSW-x64.exe
```
It copies everything to `C:\Program Files\Stillgate`, creates `C:\ProgramData\Stillgate` (only SYSTEM + Administrators can read it), and starts the **Stillgate Agent** service.
It starts in safe mode: **dry-run** (Windows changes are only logged) + **audit** (nothing is closed).

**V8. Pair the PC with the manager.**
1. On the manager: tab **Add a computer** → choose the manager's address (`192.168.1.10`) → **Create pairing string** → **Copy**. The string starts with `sg1:`, works **once**, for **10 minutes**.
2. Get the string to the visitor PC (type it, or a text file on the USB stick) and run:
   ```powershell
   & "C:\Program Files\nodejs\node.exe" "C:\Program Files\Stillgate\agent\cli.js" pair "sg1:...paste the whole string..."
   & "C:\Program Files\nodejs\node.exe" "C:\Program Files\Stillgate\agent\cli.js" status
   ```
3. On the manager the PC appears **online, Locked**. Rename it (e.g. `PC 1`).

**V9. Quick test from the manager** (nothing visible on the PC yet): **Unlock 1 hour** → shows *Unlocked* with a countdown → **Lock now** → *Locked*.

**V10. Activate the kiosk (real lockdown).**
```powershell
& "C:\Program Files\nodejs\node.exe" "C:\Program Files\Stillgate\agent\cli.js" set-dry-run off
shutdown /r /t 0
```
After the restart the agent really sets the kiosk user's shell to the kiosk screen and applies the Edge and Windows restrictions. (The administrator account keeps the normal desktop.)

**V11. Automatic sign-in as `kiosk`.** Sign in as the administrator, run **Autologon64.exe** (from the Sysinternals download) → Username `kiosk`, Domain = this PC's name (pre-filled), Password = the kiosk password → **Enable**. Or in one command:
```powershell
C:\path\to\Autologon64.exe -accepteula kiosk $env:COMPUTERNAME "Kiosk-Pass-2026!"
```
Restart:
```powershell
shutdown /r /t 0
```
The PC now signs in by itself and shows the **locked page** instead of the desktop.

**V12. Check this PC:**
- Manager → **Unlock** (custom 2 minutes) → the launcher appears → open an app and a website → let the time run out → apps close*, back to the locked page.
- In Edge, an allowed site opens; any other site is blocked.
- **Space + B + Y + S** → password box → restore password → the PC restarts into the normal desktop (maintenance, 30 min). In the manager → **End maintenance** → "restarts in 60 seconds" → back to the kiosk.
- Ctrl+Alt+Del: Task Manager, Lock, Sign out, Change password are gone.
- Unplug the network cable: the PC stays locked and never unlocks by itself.

*In **audit** mode apps are not closed yet; see the last step.

Done with this PC → go to the next one and start again at V1.

---

## Last step (after a few days): switch on enforcement
For a few days, read `C:\ProgramData\Stillgate\logs\agent.log` on each PC. Lines with `would_kill` show programs that **would** be closed. Make sure nothing important is in there (add it to the allowed apps if needed). Then, on each PC as Administrator:
```powershell
& "C:\Program Files\nodejs\node.exe" "C:\Program Files\Stillgate\agent\cli.js" set-enforcement enforce
```
From now on, programs that are not allowed are really closed, and everything closes when time runs out.

## Recommended hardening (each visitor PC)
- **BIOS/UEFI password** and boot order **internal drive only** (stops booting from a USB stick).
- Keep the administrator password only with management.

## If something goes wrong
- **Need the desktop back on one PC:** hold **Shift** while Windows starts (stops automatic sign-in) → sign in as administrator →
  ```powershell
  powershell -ExecutionPolicy Bypass -File "C:\Program Files\Stillgate\tools\emergency-restore.ps1" -KioskUser kiosk -DisableAgent
  shutdown /r /t 0
  ```
  More in `docs/RECOVERY.md`.
- **Remove Stillgate completely from a PC:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File C:\stillgate-install\tools\scripts\uninstall-agent.ps1 -KioskUser kiosk -RemoveFiles
  ```
- **Something failed:** keep `C:\ProgramData\Stillgate\logs\agent.log` and the manager's event log; they show exactly what happened.
