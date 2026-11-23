# Shows how long this PC took to start up, from the record Windows keeps of every boot.
# Used by the desktop shortcut and the npm "boot-times" command; the work is in BootTimes\.
#   -Count 40     show more boots (default 15)
#   -Json         print JSON instead of a table
#   -NoElevate    don't ask for admin rights; fail instead
#   -Pause        wait for Enter before closing (the desktop shortcut uses this)

param(
  [ValidateRange(1, 1000)][int]$Count = 15,
  [switch]$Json,
  [switch]$NoElevate,
  [switch]$Pause
)

$code = 0
try {
  Import-Module (Join-Path $PSScriptRoot 'BootTimes\BootTimes.psd1') -Force -ErrorAction Stop
  Show-BootTime -Count $Count -Json:$Json -NoElevate:$NoElevate -ErrorAction Stop
} catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  $code = 1
}
if ($Pause) {
  Write-Host ''
  Read-Host 'Press Enter to close' | Out-Null
}
exit $code
