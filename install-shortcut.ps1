# Puts a "Boot times" shortcut on the desktop that opens boot-times.ps1.
$script = Join-Path $PSScriptRoot 'boot-times.ps1'
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Boot times.lnk'))
$link.TargetPath = 'powershell.exe'
$link.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$link.WorkingDirectory = $PSScriptRoot
$link.IconLocation = 'imageres.dll,109'
$link.Description = 'How long this PC took to start up'
$link.Save()
Write-Host "Made the 'Boot times' shortcut on the desktop."
