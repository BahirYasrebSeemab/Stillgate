# Recovery: un-sticking a visitor PC

Pick the first option that works. Each one is safe to try.

## 0. The normal way (password known, kiosk shell working)
On the locked screen press **Space + B + Y + S** (together, or one after another within 3 seconds), type the restore password → the PC restarts into the normal Windows desktop for 30 minutes (maintenance). End it early from the manager ("End maintenance") or with `cli.js rearm`.

## 1. Get to the administrator account
- **Shift at boot:** hold **Shift** while Windows starts (or right after a restart) to stop automatic sign-in; the login screen appears; sign in with the **administrator** account.
- If auto sign-in still happens: on the kiosk screen press **Ctrl+Alt+Del**. Sign out is disabled for the kiosk user, but **Switch user** may be available → administrator. (UNTESTED(windows))

## 2. Run the emergency restore script (as administrator)
Open **PowerShell as Administrator** and run:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Program Files\AsdLabLock\tools\emergency-restore.ps1" -KioskUser kiosk -DisableAgent
shutdown /r /t 0
```
(If the tools folder isn't on the PC, copy `tools\scripts\emergency-restore.ps1` from the repo on a USB stick.)

What each part means:
- `powershell` starts Windows PowerShell; `-ExecutionPolicy Bypass` lets this one script run even if scripts are blocked; `-File <path>` is the script.
- `-KioskUser kiosk` is the name of the kiosk account; `-DisableAgent` also stops the agent from starting at boot (so it can't switch the shell back).
- `shutdown /r /t 0`: `/r` restart, `/t 0` after 0 seconds.

The script: stops the agent → sets the kiosk user's `Shell` to `explorer.exe` → removes the kiosk lockdown values and the Edge policies.

## 3. By hand (if scripts can't run)
In an **administrator Command Prompt**:
```bat
sc stop asd-agent
sc config asd-agent start= disabled
reg load HKU\KioskFix C:\Users\kiosk\NTUSER.DAT
reg add "HKU\KioskFix\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d explorer.exe /f
reg unload HKU\KioskFix
shutdown /r /t 0
```
- `sc stop asd-agent`: `sc` is the Service Control tool; `stop` stops the service named `asd-agent`.
- `sc config asd-agent start= disabled`: don't start it at boot. (The space after `start=` is required.)
- `reg load HKU\KioskFix C:\Users\kiosk\NTUSER.DAT`: mounts the kiosk user's registry file under the temporary name `HKU\KioskFix`. If it says the file is in use, the kiosk user is signed in: use `HKU\<kiosk SID>` instead and skip load/unload (find the SID with `wmic useraccount where name='kiosk' get sid`).
- `reg add "<key>" /v Shell /t REG_SZ /d explorer.exe /f`: `/v` value name `Shell`, `/t` type text, `/d` data `explorer.exe`, `/f` don't ask.
- `reg unload HKU\KioskFix`: unmount it again (important: an un-unloaded hive can corrupt the profile).

## 4. Safe Mode
If you can't even sign in as admin: boot into **Safe Mode** (Settings → System → Recovery → Advanced startup → Restart now → Troubleshoot → Advanced options → Startup Settings → 4). Services and custom shells don't start there. Sign in as administrator and do step 2 or 3.

## 5. Forgotten restore password
The admin sets a new one in the manager ("Restore password"). Online PCs get it immediately; offline PCs get it when they reconnect. If a PC can never reconnect, use steps 1–3.

## 6. Turning the agent back on afterwards
```powershell
Set-Service -Name asd-agent -StartupType Automatic
Start-Service -Name asd-agent
```
The agent re-applies the lockdown and sets the kiosk shell again at its next start (only when dry-run is off).
