# Stillgate

Lockdown software for shared visitor computers (built for American Space Dushanbe).

A visitor PC boots straight into a locked screen. The registration desk unlocks it for a set time from a manager app; the visitor then sees a Windows 8–style start screen with only the allowed programs and websites. When the time is up, the PC locks itself again.

- **Offline-first:** everything runs on the local network. If the manager is offline, PCs stay locked.
- **Maintenance hotkey:** Space + B + Y + S and a restore password give the normal Windows desktop back, even without the network.
- **Secure by design:** TLS with certificate pinning, HMAC challenge-response login per PC, scrypt-hashed restore password, strict input validation everywhere, hardened Electron apps.

## What's in this repository
| Folder | For | Contents |
|---|---|---|
| `visitor-pc/` | each visitor PC | `agent/` (the background service), `tools/` (install, uninstall, readiness check, emergency restore, service config) |
| `manager-pc/` | the desk PC | `tools/` (firewall and readiness scripts) |
| `docs/` | everyone | `TEST-DAY.md` (step-by-step installation), `RECOVERY.md`, `TESTING.md` |

The two desktop apps are too large for git; download them from the **[Releases](../../releases)** page:
- `Stillgate-Manager-Setup-<version>.exe`: installer for the manager PC
- `kiosk-shell-<version>-win-x64.zip`: unzip into `visitor-pc\kiosk-shell\`

## Requirements
- Windows 11 (Home is fine) on the visitor PCs, Windows 10/11 on the manager PC, all on one local network
- Node.js LTS on each visitor PC
- [WinSW](https://github.com/winsw/winsw/releases) (`WinSW-x64.exe`), placed in `visitor-pc\`

## Install
Follow **[docs/INSTALL.md](docs/INSTALL.md)**: manager PC first, then each visitor PC. For a careful first try on one PC, use [docs/TEST-DAY.md](docs/TEST-DAY.md). Keep **[docs/RECOVERY.md](docs/RECOVERY.md)** at hand.

Safe defaults: the agent starts in **dry-run** (Windows changes are only logged) and **audit** mode (nothing is closed) until you switch them off.
