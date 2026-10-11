#!/usr/bin/env node
/**
 * Shared PreToolUse / beforeShellExecution guard for Cursor + Claude Code + Codex.
 *
 * Blocks:
 * 1) High-risk PowerShell -Command shapes ($env, $_, inline script blocks, non-ASCII paths)
 * 2) PowerShell JSON / HTTP encoding paths that mangled Chinese / write BOM JSON
 *
 * Decision formats:
 * - Claude/Codex PreToolUse: hookSpecificOutput.permissionDecision
 * - Cursor beforeShellExecution: { permission: allow|deny, ... }
 */

import fs from 'node:fs';

function readHookInput() {
  const raw = fs.readFileSync(0, 'utf8').trim();
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function isCursorShellEvent(input) {
  // Cursor beforeShellExecution: top-level command, no tool_name
  return typeof input?.command === 'string' && !input?.tool_name;
}

function isShellTool(input) {
  if (isCursorShellEvent(input)) return true;
  const name = String(input?.tool_name ?? '');
  return name === 'Bash' || name === 'Shell' || name.endsWith('shell_command');
}

function getCommand(input) {
  if (typeof input?.command === 'string' && input.command) return input.command;
  const command = input?.tool_input?.command;
  return typeof command === 'string' ? command : '';
}

function hasUnescapedDollarEnv(command) {
  return /(^|[^\\])\$env:/i.test(command);
}

function hasDoubleQuotedCommandArgument(command) {
  return /-(?:command|c)\s*"/i.test(command);
}

function hasUnescapedPowerShellDollar(command) {
  return /(^|[^\\])\$(?:_|[A-Za-z][A-Za-z0-9_]*|env:)/i.test(command);
}

function hasPowerShellCommandString(command) {
  return /\b(?:pwsh|powershell)(?:\.exe)?\b[\s\S]*-(?:command|c)\b/i.test(command);
}

function usesScriptFile(command) {
  const shellMatch = /\b(?:pwsh|powershell)(?:\.exe)?\b/i.exec(command);
  if (!shellMatch) return false;

  const args = command.slice(shellMatch.index + shellMatch[0].length);
  const fileIndex = args.search(/\s-(?:file|f)\b/i);
  if (fileIndex < 0) return false;

  const commandIndex = args.search(/\s-(?:command|c)\b/i);
  return commandIndex < 0 || fileIndex < commandIndex;
}

function countSemicolons(command) {
  return (command.match(/;/g) ?? []).length;
}

function hasInlinePipelineScriptBlock(command) {
  return /\b(?:ForEach-Object|Where-Object)\s*\{/i.test(command);
}

function hasDangerousPipelineDollarUnderscore(command) {
  return /\b(?:ForEach-Object|Where-Object)\s*\{[\s\S]*\$_/i.test(command);
}

function hasNonAsciiWindowsPathInCommandString(command) {
  return /[^\x00-\x7F]/.test(command) && /[A-Za-z]:[\\/]/.test(command);
}

function hasCorruptedNonAsciiWindowsPath(command) {
  return /[A-Za-z]:[\\/][\s\S]*[\\/]\?\?(?:[\\/]|$)/.test(command);
}

function hasChinese(command) {
  return /[\u4e00-\u9fff]/.test(command);
}

function isPsJsonMangle(command) {
  if (/convertto-json/i.test(command)) return true;
  if (/\bset-content\b/i.test(command) && /\.json\b/i.test(command)) return true;
  if (/\bout-file\b/i.test(command) && /\.json\b/i.test(command)) return true;
  // redirection to .json
  if (/(>|>>)\s*['"]?[^'"\s]+\.json\b/i.test(command)) return true;
  return false;
}

function isHttpJsonPost(command) {
  return (
    /\binvoke-restmethod\b/i.test(command) ||
    /\binvoke-webrequest\b/i.test(command) ||
    /\bcurl(\.exe)?\b/i.test(command)
  );
}

function collectUtf8JsonReasons(command) {
  const reasons = [];

  // Any ConvertTo-Json in shell is unsafe for Chinese / UTF-8 API bodies on WinPS.
  if (/convertto-json/i.test(command)) {
    reasons.push(
      'Do not use PowerShell ConvertTo-Json for JSON payloads. Write UTF-8 no-BOM via Node/Python/editor Write, then POST file bytes.',
    );
  }

  if (
    (/\bset-content\b/i.test(command) || /\bout-file\b/i.test(command) || /(>|>>)\s*['"]?[^'"\s]+\.json\b/i.test(command)) &&
    /\.json\b/i.test(command) &&
    !/utf8NoBOM|UTF8Encoding\s*\(\s*\$?false\s*\)|WriteAllText/i.test(command)
  ) {
    reasons.push(
      'Do not write .json with PowerShell Set-Content/Out-File/> defaults (BOM / wrong encoding). Use Write tool, Node/Python, or [IO.File]::WriteAllText(..., UTF8Encoding($false)).',
    );
  }

  // Chinese + HTTP post via PS body string → classic mojibake path
  if (isHttpJsonPost(command) && hasChinese(command) && /\b(powershell|pwsh)\b/i.test(command)) {
    reasons.push(
      'Do not POST Chinese JSON via PowerShell Invoke-RestMethod/-Body strings. Write UTF-8 JSON file with Node/Python, then POST the file.',
    );
  }

  // PS object → ConvertTo-Json → RestMethod (even without visible Chinese in the one-liner)
  if (isPsJsonMangle(command) && isHttpJsonPost(command)) {
    reasons.push(
      'Blocked PowerShell JSON serialize + HTTP path. Prefer node/python JSON.stringify/json.dumps + UTF-8 file POST.',
    );
  }

  return reasons;
}

function collectPowerShellShapeReasons(command) {
  // Only for inline -Command; -File scripts are allowed (still subject to utf8 checks above).
  if (!hasPowerShellCommandString(command) || usesScriptFile(command)) {
    return [];
  }

  const reasons = [];

  if (countSemicolons(command) >= 2) {
    reasons.push('PowerShell -Command has 3+ inline statements; put this logic in a .ps1 and run it with -File.');
  }

  if (hasDangerousPipelineDollarUnderscore(command)) {
    reasons.push('PowerShell pipeline script block uses $_; use param($item), a named foreach loop, or a .ps1 file.');
  } else if (hasInlinePipelineScriptBlock(command)) {
    reasons.push('PowerShell inline ForEach-Object/Where-Object script blocks are high risk through shell wrappers; use a .ps1 file.');
  }

  if (hasDoubleQuotedCommandArgument(command) && hasUnescapedPowerShellDollar(command)) {
    reasons.push('PowerShell -Command is double-quoted and contains an unescaped $ variable; use a .ps1 file, wrap the whole -Command argument in single quotes for simple bash/rtk one-liners, or escape every leading $.');
  } else if (hasUnescapedDollarEnv(command)) {
    reasons.push('Unescaped $env: may be expanded by an outer shell before PowerShell runs; use [Environment]::GetEnvironmentVariable(...), \\$env:NAME when passing through bash, or a .ps1 file.');
  }

  if (hasNonAsciiWindowsPathInCommandString(command) || hasCorruptedNonAsciiWindowsPath(command)) {
    reasons.push('PowerShell -Command contains a non-ASCII or already-corrupted Windows path; pass it into a .ps1 file, use an environment variable placeholder, or use a single-quoted literal in a script file.');
  }

  return reasons;
}

function emitDeny(input, reason) {
  if (isCursorShellEvent(input)) {
    process.stdout.write(
      JSON.stringify({
        permission: 'deny',
        user_message: reason,
        agent_message: reason,
      }),
    );
    return;
  }

  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: reason,
      },
    }),
  );
}

function emitAllowCursor(input) {
  if (isCursorShellEvent(input)) {
    process.stdout.write(JSON.stringify({ permission: 'allow' }));
  }
  // Claude/Codex: exit 0 with empty/no deny = allow
}

const input = readHookInput();
const command = getCommand(input);

if (!input || !isShellTool(input) || !command) {
  emitAllowCursor(input);
  process.exit(0);
}

const reasons = [
  ...collectUtf8JsonReasons(command),
  ...collectPowerShellShapeReasons(command),
];

if (reasons.length > 0) {
  emitDeny(input, `Windows PowerShell / UTF-8 JSON safety hook blocked this command. ${reasons.join(' ')}`);
  process.exit(0);
}

emitAllowCursor(input);
process.exit(0);
