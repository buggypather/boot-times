@{
  RootModule           = 'BootTimes.psm1'
  ModuleVersion        = '1.0.0'
  GUID                 = '3646d54d-d2e0-4752-b5cb-1d477148b0de'
  Author               = 'buggypather'
  Copyright            = '(c) buggypather. MIT License.'
  Description          = 'Shows how long this PC took to start up over its last boots, and what slowed them down, from the boot record Windows already keeps (Diagnostics-Performance event log).'
  PowerShellVersion    = '5.1'
  CompatiblePSEditions = @('Desktop', 'Core')
  FunctionsToExport    = @('Show-BootTime', 'Get-BootTime', 'Get-BootSlowdown', 'Get-BootReport')
  CmdletsToExport      = @()
  VariablesToExport    = @()
  AliasesToExport      = @('boot-times')
  PrivateData          = @{
    PSData = @{
      Tags       = @('boot', 'startup', 'performance', 'eventlog', 'Windows')
      LicenseUri = 'https://github.com/buggypather/boot-times/blob/main/LICENSE'
      ProjectUri = 'https://github.com/buggypather/boot-times'
    }
  }
}
