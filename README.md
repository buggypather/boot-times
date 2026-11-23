# Boot times

Shows how long your Windows PC took to start up over its last boots, and what slowed them down.

It reads the record Windows already keeps of every boot (Event Viewer → Applications and Services
Logs → Microsoft → Windows → Diagnostics-Performance → Operational), so there's nothing running in
the background and nothing to set up.

```
Your last 3 boots (newest first), in seconds:

Started              Total Until desktop Desktop settling
-------              ----- ------------- ----------------
Mon 2026-11-23 08:02  41.3          18.9             22.4
Sun 2026-11-22 09:15  38.7          17.2             21.5
Sat 2026-11-21 10:40  55.0          19.6             35.4

Average total: 45.0 s.
```

- **Total**: from power-on to a settled desktop.
- **Until desktop**: when you could sign in and see the desktop.
- **Desktop settling**: the time after that until startup programs stopped slowing the PC.

Below the table it lists what Windows noted as slowing boots down (startup apps, drivers, services),
worst first.

Only administrators may read the boot record. If your terminal isn't running as admin, Windows asks
for admin rights and the result still appears in the same window.

## Install

### With npm

```
npm install -g boot-times
boot-times
```

### From the PowerShell Gallery

```powershell
Install-Module BootTimes -Scope CurrentUser
boot-times
```

The module also has commands that return objects, for scripts:
`Get-BootTime`, `Get-BootSlowdown` and `Get-BootReport` (these need an admin window).

### Desktop shortcut, no install

Download this repository, then run:

```powershell
powershell -ExecutionPolicy Bypass -File install-shortcut.ps1
```

and double-click **Boot times** on the desktop.

## Options

| npm             | PowerShell   | What it does                                   |
| --------------- | ------------ | ---------------------------------------------- |
| `40`, `-n 40`   | `-Count 40`  | How many boots to show (1–1000, default 15)    |
| `--json`        | `-Json`      | Print JSON instead of a table                  |
| `--no-elevate`  | `-NoElevate` | Don't ask for admin rights; fail instead       |

JSON looks like this:

```json
{
  "boots": [
    { "started": "2026-11-23T08:02:11.0000000-05:00", "totalSeconds": 41.3,
      "untilDesktopSeconds": 18.9, "settlingSeconds": 22.4 }
  ],
  "averageTotalSeconds": 41.3,
  "slowedBy": [ { "what": "OneDrive", "times": 2, "extraSeconds": 6.1 } ]
}
```

## Releasing

Bump the version in both `package.json` and `BootTimes/BootTimes.psd1`, then push a tag such as
`v1.0.1`. The Release workflow publishes to npm and the PowerShell Gallery (see the notes at the top
of `.github/workflows/release.yml` for the one-time setup).

## Related tools

See [boot-tools.md](boot-tools.md) for a curated list of other boot-related programs for Windows
and Linux: boot timers, startup program managers, pending-reboot checkers and boot media makers.

## License

MIT
