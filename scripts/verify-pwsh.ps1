#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib-pwsh-path.ps1')

$major = $PSVersionTable.PSVersion.Major
$edition = $PSVersionTable.PSEdition
$msi = $script:PreferredMsiPwsh
$onPath = Get-PwshOnPath
$preferred = Get-PreferredPwshPath

Write-Host ("Current host: {0} ({1})" -f $PSVersionTable.PSVersion, $edition)
Write-Host ("MSI path exists: {0}" -f (Test-Path -LiteralPath $msi))
if ($preferred) {
  $v = & $preferred -NoProfile -Command '$PSVersionTable.PSVersion.ToString() + " " + $PSVersionTable.PSEdition'
  Write-Host ("preferred pwsh: {0} -> {1}" -f $preferred, $v)
} else {
  Write-Host 'preferred pwsh: NOT FOUND (install MSI)'
}
if ($onPath) {
  Write-Host ("where/Get-Command pwsh: {0}" -f $onPath)
} else {
  Write-Host 'where/Get-Command pwsh: NOT FOUND'
}

if ($major -ge 7 -and $edition -eq 'Core') {
  Write-Host 'PASS: this session is PowerShell 7+'
  exit 0
}

Write-Host 'WARN: this session is not PowerShell 7+.'
Write-Host 'If MSI exists, wrap: pwsh -NoProfile -File script.ps1 and follow windows-agent-basics.md'
Write-Host 'Only if pwsh is missing: rules/windows-agent-basics-p5.md'
exit 1
