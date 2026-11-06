# Boot times

Shows how long this PC took to start up over its last boots, and what slowed them down.

It reads the record Windows already keeps of every boot (Event Viewer → Applications and Services
Logs → Microsoft → Windows → Diagnostics-Performance → Operational), so there's nothing running in
the background and nothing third-party installed.

## Use

Double-click **Boot times** on the desktop and choose **Yes** when Windows asks for admin rights
(only administrators may read the boot record).

- **Total**: from power-on to a settled desktop.
- **Until desktop**: when you could sign in and see the desktop.
- **Desktop settling**: the time after that until startup programs stopped slowing the PC.

To see more boots: `powershell -ExecutionPolicy Bypass -File boot-times.ps1 -Count 40`.

## Install the shortcut

```powershell
powershell -ExecutionPolicy Bypass -File install-shortcut.ps1
```
