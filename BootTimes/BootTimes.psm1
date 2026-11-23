# Boot times: how long this PC took to start up, read from the record Windows keeps of every boot
# (the Microsoft-Windows-Diagnostics-Performance/Operational event log). Windows only lets
# administrators read that log, so Show-BootTime asks for admin rights when it needs them and
# brings the result back into the window it was started from.

$script:Log = 'Microsoft-Windows-Diagnostics-Performance/Operational'

function Test-BootTimesAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-BootEventField($record) {
  $fields = @{}
  foreach ($item in ([xml]$record.ToXml()).Event.EventData.Data) { $fields[$item.Name] = $item.'#text' }
  $fields
}

function ConvertTo-BootSecond($ms) {
  if ($null -eq $ms -or "$ms" -eq '') { return $null }
  [math]::Round([double]$ms / 1000, 1)
}

function Read-BootEvent([hashtable]$Filter, [int]$MaxEvents = 0) {
  $arguments = @{ FilterHashtable = $Filter; ErrorAction = 'Stop' }
  if ($MaxEvents -gt 0) { $arguments.MaxEvents = $MaxEvents }
  try {
    @(Get-WinEvent @arguments)
  } catch {
    # Get-WinEvent reports "no events" as an error; that just means there's nothing yet.
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { return @() }
    if ($_.FullyQualifiedErrorId -like 'NoMatchingLogsFound*') {
      throw [InvalidOperationException]::new(
        "This copy of Windows doesn't keep the boot record (the Diagnostics-Performance log is missing or turned off), so there are no boot times to show.")
    }
    if ($_.Exception -is [UnauthorizedAccessException]) { throw (New-BootAdminError) }
    throw
  }
}

function New-BootAdminError {
  [InvalidOperationException]::new(
    'Reading the boot record needs admin rights. Run this from an admin terminal, or leave out -NoElevate to be asked.')
}

function Get-BootTime {
  <#
  .SYNOPSIS
  Lists the last boots of this PC, newest first, with how long each took in seconds.
  .DESCRIPTION
  TotalSeconds is from power-on to a settled desktop. UntilDesktopSeconds is when you could sign in
  and see the desktop. SettlingSeconds is the time after that until startup programs stopped slowing
  the PC. Needs admin rights.
  .EXAMPLE
  Get-BootTime -Count 40 | Sort-Object TotalSeconds -Descending | Select-Object -First 5
  #>
  [CmdletBinding()]
  param([ValidateRange(1, 1000)][int]$Count = 15)

  if (-not (Test-BootTimesAdmin)) { throw (New-BootAdminError) }
  foreach ($boot in (Read-BootEvent @{ LogName = $script:Log; Id = 100 } $Count)) {
    $f = Get-BootEventField $boot
    [pscustomobject]@{
      Started             = $boot.TimeCreated
      TotalSeconds        = ConvertTo-BootSecond $f.BootTime
      UntilDesktopSeconds = ConvertTo-BootSecond $f.MainPathBootTime
      SettlingSeconds     = ConvertTo-BootSecond $f.BootPostBootTime
    }
  }
}

function Get-BootSlowdown {
  <#
  .SYNOPSIS
  Lists what Windows noted as making boots slower than usual (events 101-110), worst first.
  .EXAMPLE
  Get-BootSlowdown -Since (Get-Date).AddDays(-30)
  #>
  [CmdletBinding()]
  param([datetime]$Since = [datetime]::MinValue, [ValidateRange(1, 1000)][int]$Top = 10)

  if (-not (Test-BootTimesAdmin)) { throw (New-BootAdminError) }
  $filter = @{ LogName = $script:Log; Id = 101..110 }
  if ($Since -gt [datetime]::MinValue) { $filter.StartTime = $Since }
  $items = foreach ($record in (Read-BootEvent $filter)) {
    $f = Get-BootEventField $record
    $name = if ($f.FriendlyName) { $f.FriendlyName } elseif ($f.Name) { $f.Name } else { "Event $($record.Id)" }
    [pscustomobject]@{ Name = $name; Extra = ConvertTo-BootSecond $f.DegradationTime }
  }
  @($items) | Group-Object Name | ForEach-Object {
    [pscustomobject]@{
      What         = $_.Name
      Times        = $_.Count
      ExtraSeconds = ($_.Group | Measure-Object -Property Extra -Maximum).Maximum
    }
  } | Sort-Object ExtraSeconds -Descending | Select-Object -First $Top
}

function Get-BootReport {
  <#
  .SYNOPSIS
  The last boots plus what slowed them down, as one object. Needs admin rights.
  #>
  [CmdletBinding()]
  param([ValidateRange(1, 1000)][int]$Count = 15)

  $boots = @(Get-BootTime -Count $Count)
  $slowedBy = @()
  if ($boots.Count -gt 0) {
    $oldest = ($boots | Select-Object -Last 1).Started
    $slowedBy = @(Get-BootSlowdown -Since $oldest)
  }
  [pscustomobject]@{ Boots = $boots; SlowedBy = $slowedBy }
}

function Invoke-BootReportElevated([int]$Count) {
  # Runs Get-BootReport in a hidden admin PowerShell (Windows shows its usual Yes/No prompt) and
  # reads the result back through a temporary file, so the table appears in this window.
  $out = Join-Path ([IO.Path]::GetTempPath()) ('boot-times-{0}.xml' -f [guid]::NewGuid())
  $manifest = Join-Path $PSScriptRoot 'BootTimes.psd1'
  $quote = { param($text) "'" + ($text -replace "'", "''") + "'" }
  $command = '$ErrorActionPreference = ''Stop''; ' +
    "try { Import-Module $(& $quote $manifest); `$r = Get-BootReport -Count $Count } " +
    'catch { $r = [pscustomobject]@{ Error = $_.Exception.Message } }; ' +
    "`$r | Export-Clixml -LiteralPath $(& $quote $out)"
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  $exe = (Get-Process -Id $PID).Path
  if (-not $exe) { $exe = 'powershell.exe' }

  try {
    Start-Process -FilePath $exe -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList @(
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded) | Out-Null
  } catch {
    throw 'Boot times needs admin rights to read the boot record. Run it again and choose Yes.'
  }
  if (-not (Test-Path -LiteralPath $out)) { throw 'The admin window closed without reading the boot record.' }
  try {
    $report = Import-Clixml -LiteralPath $out
  } finally {
    Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue
  }
  if ($report.PSObject.Properties['Error']) { throw $report.Error }
  $report
}

function ConvertTo-BootJson($Report) {
  $boots = @($Report.Boots | ForEach-Object {
      [ordered]@{
        started             = ([datetime]$_.Started).ToString('o')
        totalSeconds        = $_.TotalSeconds
        untilDesktopSeconds = $_.UntilDesktopSeconds
        settlingSeconds     = $_.SettlingSeconds
      }
    })
  $average = $null
  if ($boots.Count -gt 0) {
    $average = [math]::Round(($Report.Boots | Measure-Object -Property TotalSeconds -Average).Average, 1)
  }
  $slowedBy = @($Report.SlowedBy | ForEach-Object {
      [ordered]@{ what = $_.What; times = $_.Times; extraSeconds = $_.ExtraSeconds }
    })
  ConvertTo-Json -Depth 4 -InputObject ([ordered]@{
      boots               = $boots
      averageTotalSeconds = $average
      slowedBy            = $slowedBy
    })
}

function Write-BootTable($Report) {
  $boots = @($Report.Boots)
  Write-Host ''
  if ($boots.Count -eq 0) {
    Write-Host 'Windows has no boot records yet. They appear after the next restart.'
    return
  }
  Write-Host "Your last $($boots.Count) boots (newest first), in seconds:" -ForegroundColor Cyan
  $boots | ForEach-Object {
    [pscustomobject]@{
      'Started'          = ([datetime]$_.Started).ToString('ddd yyyy-MM-dd HH:mm')
      'Total'            = $_.TotalSeconds
      'Until desktop'    = $_.UntilDesktopSeconds
      'Desktop settling' = $_.SettlingSeconds
    }
  } | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() }
  $average = ($boots | Measure-Object -Property TotalSeconds -Average).Average
  Write-Host ("Average total: {0:N1} s.  'Until desktop' is when you could sign in and see the desktop;" -f $average)
  Write-Host "'Desktop settling' is the time after that until startup programs stopped slowing the PC."

  $slowedBy = @($Report.SlowedBy)
  if ($slowedBy.Count -gt 0) {
    Write-Host ''
    Write-Host 'Things that slowed these boots down, worst first:' -ForegroundColor Cyan
    $slowedBy | ForEach-Object {
      [pscustomobject]@{ 'What' = $_.What; 'Times' = $_.Times; 'Extra seconds' = $_.ExtraSeconds }
    } | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_.TrimEnd() }
  }
}

function Show-BootTime {
  <#
  .SYNOPSIS
  Shows how long this PC took to start up over its last boots, and what slowed them down.
  .DESCRIPTION
  Reads the boot record Windows keeps in the Diagnostics-Performance event log. If this window isn't
  running as admin, Windows asks for admin rights and the result still appears here.
  .PARAMETER Count
  How many boots to show (default 15).
  .PARAMETER Json
  Print the result as JSON instead of a table.
  .PARAMETER NoElevate
  Don't ask for admin rights; fail instead if this window isn't already admin.
  .EXAMPLE
  boot-times -Count 40
  #>
  [CmdletBinding()]
  param(
    [ValidateRange(1, 1000)][int]$Count = 15,
    [switch]$Json,
    [switch]$NoElevate
  )

  $report = if (Test-BootTimesAdmin) {
    Get-BootReport -Count $Count
  } elseif ($NoElevate) {
    throw (New-BootAdminError)
  } else {
    Invoke-BootReportElevated -Count $Count
  }
  if ($Json) { ConvertTo-BootJson $report } else { Write-BootTable $report }
}

New-Alias -Name boot-times -Value Show-BootTime -Force
Export-ModuleMember -Function Get-BootTime, Get-BootSlowdown, Get-BootReport, Show-BootTime -Alias boot-times
