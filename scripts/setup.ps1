#Requires -Version 5.1
# One-shot: install MSI pwsh, PATH first, copy hook, print merge steps.
# Does NOT edit Cursor/Claude/Codex settings files.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $here
. (Join-Path $here 'lib-pwsh-path.ps1')

Write-Output '=== 1 install MSI pwsh ==='
& (Join-Path $here 'install-pwsh.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output '=== 2 PATH: PowerShell 7 first ==='
& (Join-Path $here 'path-pwsh-first.ps1')

Write-Output '=== 3 copy hook ==='
$homeDir = [Environment]::GetFolderPath('UserProfile')
$hookSrc = Join-Path $root 'hooks\windows-powershell-safety.mjs'
$hookDir = Join-Path $homeDir '.agents\hooks'
$hookDest = Join-Path $hookDir 'windows-powershell-safety.mjs'
if (-not (Test-Path -LiteralPath $hookSrc)) { throw "missing $hookSrc" }
New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
Copy-Item -LiteralPath $hookSrc -Destination $hookDest -Force
$hookFwd = ($hookDest -replace '\\', '/')
Write-Output ("OK hook -> {0}" -f $hookFwd)

$repoFwd = ($root -replace '\\', '/')
$msi = $script:PreferredMsiPwsh

Write-Output ''
Write-Output '=== 4 next steps (script does NOT edit your settings) ==='
Write-Output 'Tip: ask an AI agent to merge the JSON/TOML below for tools you have.'
Write-Output 'Missing Cursor / Claude / Codex is fine - skip those lines; verify will SKIP them.'
Write-Output ''
Write-Output '--- A. Cursor (if installed) ---'
Write-Output '  1) User Rules (often manual): Settings -> Rules -> User Rules'
Write-Output '     Paste FULL text of rules/windows-agent-basics.md (NOT the p5 file).'
Write-Output '     Cursor User Rules do not support @-import from this folder.'
Write-Output '  2) Merge examples/cursor-terminal-settings.json'
Write-Output '     -> %APPDATA%\Cursor\User\settings.json'
Write-Output '  3) Merge examples/cursor-hooks.json'
Write-Output '     -> %USERPROFILE%\.cursor\hooks.json'
Write-Output ("     Replace HOOK_PATH with: {0}" -f $hookFwd)
Write-Output ''
Write-Output '--- B. Claude Code (if installed) ---'
Write-Output '  1) %USERPROFILE%\AGENTS.md: use examples/AGENTS.snippet.md'
Write-Output ("     Replace REPO with: {0}" -f $repoFwd)
Write-Output '  2) Merge examples/claude-settings.shell.json + claude-settings.hooks.json'
Write-Output '     -> %USERPROFILE%\.claude\settings.json'
Write-Output ("     Replace HOOK_PATH with: {0}" -f $hookFwd)
Write-Output ''
Write-Output '--- C. Codex (if installed) ---'
Write-Output '  1) %USERPROFILE%\.codex\AGENTS.md: same AGENTS.snippet.md'
Write-Output ("  2) %USERPROFILE%\.codex\config.toml: [windows] shell_path = '{0}'" -f $msi)
Write-Output '  3) Merge examples/codex-hooks.json -> %USERPROFILE%\.codex\hooks.json'
Write-Output ("     Replace HOOK_PATH with: {0}" -f $hookFwd)
Write-Output ''
Write-Output '--- D. Restart + verify ---'
Write-Output '  Fully quit Cursor / Claude Code / Codex (Reload is not enough).'
Write-Output '  New terminal:'
Write-Output '    powershell -NoProfile -File scripts\verify-setup.ps1'
Write-Output ''
Write-Output 'Do not delete %LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe (Store alias).'
Write-Output 'Do not always-on both basics.md and basics-p5.md.'