# Pester 5 tests for the BootTimes module, using made-up boot records instead of the real log.
# Run with: Invoke-Pester -Path tests

BeforeAll {
  Import-Module (Join-Path $PSScriptRoot '..\BootTimes\BootTimes.psd1') -Force

  function global:New-FakeBootEvent([int]$Id, [datetime]$When, [hashtable]$Data) {
    $items = foreach ($key in $Data.Keys) { "<Data Name=""$key"">$($Data[$key])</Data>" }
    $xml = '<Event xmlns="http://schemas.microsoft.com/win/2004/08/events/event"><EventData>' +
      ($items -join '') + '</EventData></Event>'
    $fake = [pscustomobject]@{ Id = $Id; TimeCreated = $When; Xml = $xml }
    $fake | Add-Member -MemberType ScriptMethod -Name ToXml -Value { $this.Xml }
    $fake
  }

  function global:New-FakeWinEventError([string]$Id) {
    [System.Management.Automation.ErrorRecord]::new(
      [Exception]::new('fake'), "$Id,Microsoft.PowerShell.Commands.GetWinEventCommand", 'ObjectNotFound', $null)
  }
}

AfterAll {
  Remove-Module BootTimes -ErrorAction SilentlyContinue
}

Describe 'BootTimes with two boots' {
  BeforeEach {
    Mock -ModuleName BootTimes Test-BootTimesAdmin { $true }
    Mock -ModuleName BootTimes Get-WinEvent -ParameterFilter { @($FilterHashtable.Id) -contains 100 } {
      New-FakeBootEvent 100 ([datetime]'2026-11-23T08:02:00') @{ BootTime = 41300; MainPathBootTime = 18900; BootPostBootTime = 22400 }
      New-FakeBootEvent 100 ([datetime]'2026-11-22T09:15:00') @{ BootTime = 38700; MainPathBootTime = 17200; BootPostBootTime = 21500 }
    }
    Mock -ModuleName BootTimes Get-WinEvent -ParameterFilter { @($FilterHashtable.Id) -contains 101 } {
      New-FakeBootEvent 101 ([datetime]'2026-11-23T08:03:00') @{ Name = 'onedrive.exe'; FriendlyName = 'OneDrive'; DegradationTime = 6100 }
      New-FakeBootEvent 101 ([datetime]'2026-11-22T09:16:00') @{ Name = 'onedrive.exe'; FriendlyName = 'OneDrive'; DegradationTime = 4000 }
      New-FakeBootEvent 103 ([datetime]'2026-11-22T09:16:00') @{ Name = 'Spooler'; DegradationTime = 9000 }
    }
  }

  It 'Get-BootTime turns milliseconds into seconds' {
    $boots = @(Get-BootTime -Count 5)
    $boots.Count | Should -Be 2
    $boots[0].TotalSeconds | Should -Be 41.3
    $boots[0].UntilDesktopSeconds | Should -Be 18.9
    $boots[0].SettlingSeconds | Should -Be 22.4
    $boots[0].Started | Should -Be ([datetime]'2026-11-23T08:02:00')
  }

  It 'Get-BootTime passes the count to Get-WinEvent' {
    Get-BootTime -Count 7 | Out-Null
    Should -Invoke -ModuleName BootTimes Get-WinEvent -Times 1 -ParameterFilter { $MaxEvents -eq 7 }
  }

  It 'Get-BootSlowdown groups by name, worst first' {
    $slow = @(Get-BootSlowdown)
    $slow.Count | Should -Be 2
    $slow[0].What | Should -Be 'Spooler'
    $slow[0].ExtraSeconds | Should -Be 9
    $slow[1].What | Should -Be 'OneDrive'
    $slow[1].Times | Should -Be 2
    $slow[1].ExtraSeconds | Should -Be 6.1
  }

  It 'Show-BootTime -Json gives boots, an average and what slowed them' {
    $text = Show-BootTime -Count 5 -Json | Out-String
    $data = $text | ConvertFrom-Json
    @($data.boots).Count | Should -Be 2
    # pwsh turns ISO dates into DateTime when reading JSON, so check the text itself.
    $text | Should -Match '"started":\s*"2026-11-23T08:02:00'
    $data.boots[1].totalSeconds | Should -Be 38.7
    $data.averageTotalSeconds | Should -Be 40
    $data.slowedBy[0].what | Should -Be 'Spooler'
  }

  It 'Show-BootTime prints a table' {
    $text = Show-BootTime -Count 5 6>&1 | Out-String
    $text | Should -Match 'Your last 2 boots'
    $text | Should -Match 'Mon 2026-11-23 08:02'
    $text | Should -Match 'Average total: 40\.0 s'
    $text | Should -Match 'OneDrive'
  }

  It 'the boot-times alias is exported' {
    (Get-Command boot-times).ResolvedCommand.Name | Should -Be 'Show-BootTime'
  }
}

Describe 'BootTimes with one boot' {
  BeforeEach {
    Mock -ModuleName BootTimes Test-BootTimesAdmin { $true }
    Mock -ModuleName BootTimes Get-WinEvent -ParameterFilter { @($FilterHashtable.Id) -contains 100 } {
      New-FakeBootEvent 100 ([datetime]'2026-11-23T08:02:00') @{ BootTime = 41300; MainPathBootTime = 18900; BootPostBootTime = 22400 }
    }
    Mock -ModuleName BootTimes Get-WinEvent -ParameterFilter { @($FilterHashtable.Id) -contains 101 } {
      throw (New-FakeWinEventError 'NoMatchingEventsFound')
    }
  }

  It 'JSON keeps boots and slowedBy as lists' {
    $text = Show-BootTime -Json | Out-String
    $text | Should -Match '"boots":\s*\['
    $text | Should -Match '"slowedBy":\s*\[\s*\]'
  }
}

Describe 'BootTimes edge cases' {
  It 'says when there are no boot records yet' {
    Mock -ModuleName BootTimes Test-BootTimesAdmin { $true }
    Mock -ModuleName BootTimes Get-WinEvent { throw (New-FakeWinEventError 'NoMatchingEventsFound') }
    (Show-BootTime 6>&1 | Out-String) | Should -Match 'no boot records yet'
    $data = Show-BootTime -Json | Out-String | ConvertFrom-Json
    @($data.boots).Count | Should -Be 0
    $data.averageTotalSeconds | Should -BeNullOrEmpty
  }

  It 'explains a missing boot log' {
    Mock -ModuleName BootTimes Test-BootTimesAdmin { $true }
    Mock -ModuleName BootTimes Get-WinEvent { throw (New-FakeWinEventError 'NoMatchingLogsFound') }
    { Get-BootTime } | Should -Throw "*doesn't keep the boot record*"
  }

  It 'fails without admin when told not to ask' {
    Mock -ModuleName BootTimes Test-BootTimesAdmin { $false }
    { Show-BootTime -NoElevate } | Should -Throw '*needs admin rights*'
  }
}
