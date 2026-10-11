#Requires -Version 5.1
# ASCII-only so Windows PowerShell 5.1 can parse this file.
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'lib-pwsh-path.ps1')

$msi = $script:PreferredMsiPwsh
$pass = 0
$fail = 0
$skip = 0

function Check([string]$name, [bool]$ok, [string]$detail) {
  $script:pass += [int]$ok
  $script:fail += [int](-not $ok)
  $mark = if ($ok) { 'PASS' } else { 'FAIL' }
  Write-Output ("[{0}] {1} | {2}" -f $mark, $name, $detail)
}

function Skip([string]$name, [string]$why) {
  $script:skip += 1
  Write-Output ("[SKIP] {0} | {1}" -f $name, $why)
}

Check 'MSI pwsh exists' (Test-Path -LiteralPath $msi) $msi

$ver = ''
$edition = ''
if (Test-Path -LiteralPath $msi) {
  try {
    $out = & $msi -NoProfile -Command '[string]$PSVersionTable.PSVersion.Major; [string]$PSVersionTable.PSEdition' 2>&1
    $lines = @($out | ForEach-Object { [string]$_ })
    $ver = $lines[0]
    $edition = $lines[1]
  } catch {
    $ver = $_.Exception.Message
  }
}
Check 'MSI pwsh runs 7 Core' (($ver -eq '7') -and ($edition -eq 'Core')) ("Major={0} Edition={1}" -f $ver, $edition)

$hostExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
Write-Output ("[INFO] this-host={0} ver={1} edition={2}" -f $hostExe, $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

$machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$user = [Environment]::GetEnvironmentVariable('Path', 'User')
$fresh = $machine + ';' + $user
$old = [Environment]::GetEnvironmentVariable('Path', 'Process')
[Environment]::SetEnvironmentVariable('Path', $fresh, 'Process')
$whereOut = @(& where.exe pwsh 2>&1 | ForEach-Object { [string]$_ })
[Environment]::SetEnvironmentVariable('Path', $old, 'Process')
$whereFirst = $whereOut | Select-Object -First 1
Check 'where pwsh (registry PATH) first is MSI' ($whereFirst -ieq $msi) ("first={0}" -f $whereFirst)

$homeDir = [Environment]::GetFolderPath('UserProfile')
$appData = [Environment]::GetFolderPath('ApplicationData')

$cursorSettings = Join-Path $appData 'Cursor\User\settings.json'
if (Test-Path -LiteralPath $cursorSettings) {
  $cs = Get-Content -LiteralPath $cursorSettings -Raw
  Check 'Cursor settings pin MSI pwsh' ($cs -match [regex]::Escape('C:\\Program Files\\PowerShell\\7\\pwsh.exe')) $cursorSettings
} else {
  Skip 'Cursor settings.json' 'not found (Cursor not installed or never opened - OK)'
}

$cursorHooks = Join-Path $homeDir '.cursor\hooks.json'
if (Test-Path -LiteralPath $cursorHooks) {
  $ch = Get-Content -LiteralPath $cursorHooks -Raw
  Check 'Cursor hooks.json references safety hook' ($ch -match 'windows-powershell-safety\.mjs') $cursorHooks
} else {
  Skip 'Cursor hooks.json' 'not found (optional until you merge examples/cursor-hooks.json)'
}

$claudeSettings = Join-Path $homeDir '.claude\settings.json'
if (Test-Path -LiteralPath $claudeSettings) {
  $cl = Get-Content -LiteralPath $claudeSettings -Raw
  Check 'Claude PowerShell tool on' ($cl -match 'CLAUDE_CODE_USE_POWERSHELL_TOOL') $claudeSettings
  Check 'Claude defaultShell powershell' ($cl -match '"defaultShell":\s*"powershell"') 'defaultShell'
  if ($cl -match 'windows-powershell-safety\.mjs') {
    Check 'Claude settings hooks safety hook' $true 'hooks mention safety.mjs'
  } else {
    Write-Output '[INFO] Claude settings.json has no windows-powershell-safety.mjs yet (merge claude-settings.hooks.json)'
  }
} else {
  Skip 'Claude settings.json' 'not found (Claude Code not installed - OK)'
}

$codexCfg = Join-Path $homeDir '.codex\config.toml'
if (Test-Path -LiteralPath $codexCfg) {
  $cx = Get-Content -LiteralPath $codexCfg -Raw
  Check 'Codex shell_path is MSI' ($cx -match [regex]::Escape("C:\Program Files\PowerShell\7\pwsh.exe")) $codexCfg
  Check 'Codex shell_path is not WindowsApps' ($cx -notmatch 'WindowsApps\\Microsoft.PowerShell') 'no Store path'
} else {
  Skip 'Codex config.toml' 'not found (Codex not installed - OK)'
}

$codexHooks = Join-Path $homeDir '.codex\hooks.json'
if (Test-Path -LiteralPath $codexHooks) {
  $cxh = Get-Content -LiteralPath $codexHooks -Raw
  Check 'Codex hooks.json references safety hook' ($cxh -match 'windows-powershell-safety\.mjs') $codexHooks
} else {
  Skip 'Codex hooks.json' 'not found (optional until you merge examples/codex-hooks.json)'
}

$agents = Join-Path $homeDir 'AGENTS.md'
if (Test-Path -LiteralPath $agents) {
  $ag = Get-Content -LiteralPath $agents -Raw
  Check 'AGENTS.md references basics.md' ($ag -match 'windows-agent-basics.md') $agents
  Check 'AGENTS.md does not always-import p5' ($ag -notmatch '@[^ \r\n]*windows-agent-basics-p5.md') 'p5 not @imported'
} else {
  Skip 'AGENTS.md' 'not found (needed for Claude/Codex routing; Cursor uses User Rules instead)'
}

$hook = Join-Path $homeDir '.agents\hooks\windows-powershell-safety.mjs'
Check 'hook copied' (Test-Path -LiteralPath $hook) $hook

Write-Output ("=== summary pass={0} fail={1} skip={2} ===" -f $pass, $fail, $skip)
Write-Output 'SKIP = tool/config absent (normal). FAIL = installed tool misconfigured.'
Write-Output 'Note: Cursor User Rules paste cannot be verified from disk by this script.'
if ($fail -gt 0) { exit 1 }
exit 0