# Shows how long this PC took to start up, from the record Windows keeps of every boot
# (the Diagnostics-Performance event log). Windows only lets administrators read that log,
# so the script asks for admin rights when it starts.

param([int]$Count = 15)

$ErrorActionPreference = 'Stop'
$Log = 'Microsoft-Windows-Diagnostics-Performance/Operational'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  try {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Count $Count"
  } catch {
    Write-Host 'Boot times needs admin rights to read the boot record. Open it again and choose Yes.'
    Read-Host 'Press Enter to close'
  }
  exit
}

function Get-EventFields($record) {
  $fields = @{}
  foreach ($item in ([xml]$record.ToXml()).Event.EventData.Data) { $fields[$item.Name] = $item.'#text' }
  $fields
}

function Seconds($ms) { [math]::Round([double]$ms / 1000, 1) }

try {
  $boots = @(Get-WinEvent -FilterHashtable @{ LogName = $Log; Id = 100 } -MaxEvents $Count)
} catch {
  $boots = @()
}

Write-Host ''
if ($boots.Count -eq 0) {
  Write-Host 'Windows has no boot records yet. They appear after the next restart.'
} else {
  Write-Host "Your last $($boots.Count) boots (newest first), in seconds:" -ForegroundColor Cyan
  $rows = foreach ($boot in $boots) {
    $f = Get-EventFields $boot
    [pscustomobject]@{
      'Started'         = $boot.TimeCreated.ToString('ddd yyyy-MM-dd HH:mm')
      'Total'           = Seconds $f.BootTime
      'Until desktop'   = Seconds $f.MainPathBootTime
      'Desktop settling'= Seconds $f.BootPostBootTime
    }
  }
  $rows | Format-Table -AutoSize | Out-Host
  $average = ($rows | Measure-Object -Property Total -Average).Average
  Write-Host ("Average total: {0:N1} s.  'Until desktop' is when you could sign in and see the desktop;" -f $average)
  Write-Host "'Desktop settling' is the time after that until startup programs stopped slowing the PC."

  # Windows also notes what made a boot slower than usual (events 101-110).
  $since = ($boots | Select-Object -Last 1).TimeCreated
  try {
    $slow = @(Get-WinEvent -FilterHashtable @{ LogName = $Log; Id = 101..110; StartTime = $since })
  } catch {
    $slow = @()
  }
  if ($slow.Count -gt 0) {
    Write-Host ''
    Write-Host 'Things that slowed these boots down, worst first:' -ForegroundColor Cyan
    $slow | ForEach-Object {
      $f = Get-EventFields $_
      $name = if ($f.FriendlyName) { $f.FriendlyName } else { $f.Name }
      [pscustomobject]@{ Name = $name; 'Extra seconds' = Seconds $f.DegradationTime }
    } | Group-Object Name | ForEach-Object {
      [pscustomobject]@{
        'What'          = $_.Name
        'Times'         = $_.Count
        'Extra seconds' = ($_.Group | Measure-Object -Property 'Extra seconds' -Maximum).Maximum
      }
    } | Sort-Object 'Extra seconds' -Descending | Select-Object -First 10 | Format-Table -AutoSize | Out-Host
  }
}

Write-Host ''
Read-Host 'Press Enter to close'
