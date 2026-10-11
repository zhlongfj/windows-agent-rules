#Requires -Version 5.1
# Put C:\Program Files\PowerShell\7 first on PATH.
# Do not delete the WindowsApps pwsh.exe alias; PATH order is enough.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib-pwsh-path.ps1')

$pwshDir = 'C:\Program Files\PowerShell\7'
if (-not (Test-Path -LiteralPath (Join-Path $pwshDir 'pwsh.exe'))) {
  Write-Output 'FAIL MSI pwsh missing. Run scripts/install-pwsh.ps1 first.'
  exit 1
}

function Move-PwshFirst {
  param([ValidateSet('Machine', 'User')][string]$Scope)
  $raw = [Environment]::GetEnvironmentVariable('Path', $Scope)
  if ([string]::IsNullOrWhiteSpace($raw)) {
    if ($Scope -eq 'User') {
      [Environment]::SetEnvironmentVariable('Path', $pwshDir, 'User')
      Write-Output ("OK {0} PATH set to {1}" -f $Scope, $pwshDir)
    } else {
      Write-Output ("SKIP {0} PATH empty" -f $Scope)
    }
    return $true
  }
  $parts = @($raw -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
  $kept = New-Object System.Collections.Generic.List[string]
  foreach ($p in $parts) {
    if (($p.TrimEnd('\')) -ieq $pwshDir) { continue }
    $kept.Add($p) | Out-Null
  }
  $new = [string]::Join(';', @($pwshDir) + $kept.ToArray())
  try {
    [Environment]::SetEnvironmentVariable('Path', $new, $Scope)
    Write-Output ("OK {0} PATH: {1} moved first" -f $Scope, $pwshDir)
    return $true
  } catch {
    Write-Output ("FAIL {0} PATH: {1}" -f $Scope, $_.Exception.Message)
    return $false
  }
}

$userOk = Move-PwshFirst -Scope User
$machineOk = Move-PwshFirst -Scope Machine
if (-not $machineOk) {
  Write-Output 'Machine PATH needs elevation. Re-run this script in an admin prompt.'
}

if ($userOk) { exit 0 }
exit 1
