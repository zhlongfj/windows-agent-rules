#Requires -Version 5.1
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib-pwsh-path.ps1')

$info = [ordered]@{
  PSVersion      = $PSVersionTable.PSVersion.ToString()
  PSEdition      = $PSVersionTable.PSEdition
  HostExe        = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  MsiPwsh        = $script:PreferredMsiPwsh
  MsiExists      = [string](Test-Path -LiteralPath $script:PreferredMsiPwsh)
  PreferredPwsh  = [string](Get-PreferredPwshPath)
  PathPwsh       = [string](Get-PwshOnPath)
  AndChainInHost = if ($PSVersionTable.PSVersion.Major -ge 7) { 'supported' } else { 'not supported' }
}

$info.GetEnumerator() | ForEach-Object {
  Write-Output ("{0}={1}" -f $_.Key, $_.Value)
}
