# Service wrapper (WinSW)

Windows services must answer the Service Control Manager's start/stop calls, and plain `node.exe` can't do that.
**WinSW** is a small, well-known wrapper that does it for us: it starts `node main.js` as SYSTEM, restarts it if it crashes, and sends Ctrl+C on stop.

**You download WinSW yourself** (the repo never contains executables):
1. Go to the official releases page: https://github.com/winsw/winsw/releases
2. Download `WinSW-x64.exe` (v3 is what `asd-agent.xml` was checked against).
3. Pass its path to `tools/scripts/install-agent.ps1 -WinSWExe <path>`. The script copies it to `C:\Program Files\AsdLabLock\agent\asd-agent.exe` next to `asd-agent.xml`.

Useful commands (Administrator PowerShell, in `C:\Program Files\AsdLabLock\agent`):

| Command | What it does |
|---|---|
| `.\asd-agent.exe status` | is the service installed, running or stopped |
| `.\asd-agent.exe stop` / `start` / `restart` | control it |
| `.\asd-agent.exe uninstall` | remove the service (use `uninstall-agent.ps1` instead; it also restores the shell) |
