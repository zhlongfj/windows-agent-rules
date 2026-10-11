#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib-pwsh-path.ps1')

$pwshPath = Get-PreferredPwshPath
if (-not $pwshPath) {
  Write-Output 'FAIL no MSI pwsh. Run scripts/install-pwsh.ps1'
  Write-Output 'Do not use %LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe'
  exit 1
}

Write-Output ("pwsh={0}" -f $pwshPath)
Write-Output ''
Write-Output '[windows]'
Write-Output ("shell_path = '{0}'" -f $pwshPath)
