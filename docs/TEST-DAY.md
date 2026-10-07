# Test day at ASD: one visitor PC

Goal: prove the whole system on **one** visitor PC. **Don't touch the other PCs** until every step here has passed.
Work through it in order, phase by phase. Each phase can be undone. If something goes wrong, see **"If something goes wrong"** at the end.

## Bring on a USB stick
The `stillgate-deploy` folder (prepared on the dev PC), plus two downloads **you make yourself**:
- **Node.js LTS installer** (Windows x64 `.msi`) from https://nodejs.org
- **WinSW-x64.exe** from https://github.com/winsw/winsw/releases (put it in `stillgate-deploy\visitor-pc\`)
- Optional: **Sysinternals Autologon** from Microsoft (for phase 3)

You also need: the visitor PC's **administrator password**, and a manager PC on the **same network** (your laptop is fine for the test).

---

## Phase 0: Manager PC (5 min)
1. Run `stillgate-deploy\manager-pc\Stillgate-Manager-Setup-…exe`, then start **Stillgate Manager**.
   - If Windows asks about the firewall, allow it on **Private networks** for today's test. Later, run `firewall-manager.ps1` to limit it to the visitor PCs.
2. Tab **Restore password** → set a password (at least 10 characters). **Write it down safely.**
3. Note this PC's IP address: run `ipconfig` and look for the "IPv4 Address" of the Wi-Fi/Ethernet adapter, e.g. `192.168.1.10`.

## Phase 1: Install on the test PC, nothing visible changes (20 min)
Everything here is done while signed in as the **administrator**.
1. **Create the kiosk user** in an Administrator Command Prompt:
   ```bat
   net user kiosk SomeLongPassword123 /add
   ```
   - `net user`: manage local accounts. `kiosk`: the account name (English letters only). Then the password. `/add`: create it.
   - New accounts are **standard users** by default (correct; do NOT make it admin).
2. **Sign in once as `kiosk`**, wait for the desktop, then **sign out** and go back to the administrator. This creates the kiosk user's profile.
3. Install **Node.js LTS** (defaults are fine).
4. Copy `stillgate-deploy\visitor-pc` to the PC (e.g. `C:\stillgate-install`).
5. **Check the PC** (read-only, changes nothing). In PowerShell **as Administrator**:
   ```powershell
   cd C:\stillgate-install\tools\scripts
   powershell -ExecutionPolicy Bypass -File check-pc.ps1 -KioskUser kiosk -ManagerIP 192.168.1.10
   ```
   All lines should be `OK` or `INFO`. Fix any `FAIL` first. (The manager must be running for the last check.)
6. **Install:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File install-agent.ps1 -KioskUser kiosk -AgentSource C:\stillgate-install\agent -KioskShellSource C:\stillgate-install\kiosk-shell -WinSWExe C:\stillgate-install\WinSW-x64.exe
   ```
7. **Pair:** in the manager, tab **Add a computer** → choose the manager's address → **Create pairing string** → **Copy**. Send the string to the test PC (USB stick, or type it). Then:
   ```powershell
   & "C:\Program Files\nodejs\node.exe" "C:\Program Files\Stillgate\agent\cli.js" pair "sg1:…paste…"
   & "C:\Program Files\nodejs\node.exe" "C:\Program Files\Stillgate\agent\cli.js" status
   ```
8. ✅ **Check:** the manager shows the PC **online, Locked, "up to date", tags "dry-run" + "audit only"**. Click **Unlock 1 hour** → it shows Unlocked with a countdown; **Lock now** → Locked.
   Nothing changes on the PC's screen yet; that's correct (dry-run).
9. Look at `C:\ProgramData\Stillgate\logs\agent.log`: you should see `dry_run` lines (what it *would* change) and `would_kill` lines are fine.

## Phase 2: Try the kiosk screen by hand, normal Windows still underneath (15 min)
1. Sign in as **kiosk** (normal desktop, nothing locked yet).
2. Run `C:\Program Files\Stillgate\kiosk-shell\kiosk-shell.exe`. It goes full screen and shows the **locked page**.
3. ✅ From the manager: **Unlock 1 hour** → the **launcher** appears with a countdown → open an app and a site (Edge opens).
   First add some apps/sites in the manager's **Allowed apps & sites** tab and press **Save**.
4. ✅ Press **Space + B + Y + S** (together, or one after another) → password box. Wrong password 5× → "Try again in 60 seconds". After that, the right password → "Maintenance" page. (No restart happens: dry-run.) Then click **End maintenance** in the manager.
5. Leave the kiosk screen: **Ctrl+Alt+Del → Task Manager → end "kiosk-shell"** (Task Manager still works in this phase). Sign out.

## Phase 3: Real lockdown (30 min). Have `docs/RECOVERY.md` ready
Back as the **administrator**:
1. Turn dry-run off: `& "C:\Program Files\nodejs\node.exe" "C:\Program Files\Stillgate\agent\cli.js" set-dry-run off`
   Then **restart the PC**. At start-up the agent now really sets the kiosk user's shell and applies the Edge and Windows restrictions. **Enforcement stays "audit"**: nothing gets closed yet.
2. Sign in as **kiosk** (type the password once; for automatic sign-in later, run **Autologon**, enter `kiosk` + password).
3. ✅ **Instead of the desktop, the kiosk screen appears.** No taskbar, no Start menu.
4. ✅ Unlock from the manager → launcher → apps/sites open. In Edge, an allowed site opens; any other site is blocked; InPrivate/downloads are blocked.
5. ✅ Let a short unlock (e.g. custom 2 minutes) run out → back to the locked page.
6. ✅ **Hotkey + right password** → the PC **restarts** into the **normal Windows desktop** for the kiosk user (maintenance, 30 min). Then **End maintenance** in the manager → a "restarts in 60 seconds" message → back to the kiosk screen.
7. ✅ Ctrl+Alt+Del on the kiosk screen: Task Manager, Lock, Sign out and Change password should be **gone**.
8. ✅ Unplug the network (or close the manager): the PC stays as it is and **never unlocks by itself**.

## Phase 4: Later days, not on test day
- Read `would_kill` lines in `agent.log` for a few days. Only then: `cli.js set-enforcement enforce` (programs not on the list then really get closed).
- Then repeat Phases 1–3 on each other PC (pairing string → one per PC), and run `firewall-manager.ps1 -VisitorIPs …` on the manager PC.

---

## Write down for every step
✅ / ❌ and what you saw. **Copy `C:\ProgramData\Stillgate\logs\agent.log` and the manager's event log** if something fails; they show exactly what happened.

## If something goes wrong
- **Kiosk screen stuck, password unknown:** hold **Shift** while Windows starts → sign in as administrator → `docs/RECOVERY.md` step 2:
  `powershell -ExecutionPolicy Bypass -File "C:\Program Files\Stillgate\tools\emergency-restore.ps1" -KioskUser kiosk -DisableAgent` then `shutdown /r /t 0`.
- **Black screen after sign-in as kiosk:** same as above (the kiosk shell didn't start). Bring `agent.log` home.
- **Remove everything:** `uninstall-agent.ps1 -KioskUser kiosk -RemoveFiles`.
