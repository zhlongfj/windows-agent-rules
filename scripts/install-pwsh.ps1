#Requires -Version 5.1
# Install PowerShell 7 MSI (WiX), not the Store MSIX / WindowsApps package.
# winget's default installer type for Microsoft.PowerShell 7.6+ is MSIX.
# Same version already installed as MSIX => need --force --installer-type wix.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib-pwsh-path.ps1')

$msi = $script:PreferredMsiPwsh
if (Test-Path -LiteralPath $msi) {
  Write-Output ("SKIP already installed: {0}" -f $msi)
  exit 0
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
  Write-Output 'FAIL winget.exe not found. Install App Installer, then rerun.'
  Write-Output 'Manual MSI: https://github.com/PowerShell/PowerShell/releases'
  Write-Output 'Asset: PowerShell-*-win-x64.msi'
  exit 1
}

function Invoke-WingetMsi {
  param([switch]$Force)
  $args = @(
    'install',
    '--id', 'Microsoft.PowerShell',
    '--source', 'winget',
    '--installer-type', 'wix',
    '--accept-package-agreements',
    '--accept-source-agreements',
    '--disable-interactivity'
  )
  if ($Force) { $args += '--force' }
  Write-Output ("RUN winget {0}" -f ($args -join ' '))
  & winget.exe @args
  return $LASTEXITCODE
}

$code = Invoke-WingetMsi
if (-not (Test-Path -LiteralPath $msi)) {
  Write-Output 'MSI path still missing. Retry with --force (needed when Store MSIX same version is already installed).'
  $code = Invoke-WingetMsi -Force
}

if (Test-Path -LiteralPath $msi) {
  Write-Output ("PASS MSI pwsh: {0}" -f $msi)
  exit 0
}

Write-Output 'FAIL MSI pwsh not at C:\Program Files\PowerShell\7\pwsh.exe'
Write-Output 'Do not pin WindowsApps\pwsh.exe (Store alias). Rerun this script in an elevated prompt.'
Write-Output ("winget exit={0}" -f $code)
exit 1
