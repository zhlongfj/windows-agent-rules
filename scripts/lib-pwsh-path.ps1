# ASCII-only. Dot-source from other scripts in this folder.
$script:PreferredMsiPwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'

function Get-PreferredPwshPath {
  if (Test-Path -LiteralPath $script:PreferredMsiPwsh) {
    return $script:PreferredMsiPwsh
  }
  $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
  if (-not $cmd) { return $null }
  $src = [string]$cmd.Source
  if ($src -like '*\WindowsApps\*') { return $null }
  return $src
}

function Get-PwshOnPath {
  $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($cmd) { return [string]$cmd.Source }
  return $null
}

function Test-MsiPwsh {
  return (Test-Path -LiteralPath $script:PreferredMsiPwsh)
}
