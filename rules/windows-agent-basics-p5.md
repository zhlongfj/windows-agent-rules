# Windows Agent Basics (PowerShell 5.1 / Legacy)

> **适用（仅 fallback）：** 当前命令实际跑在 **Windows PowerShell 5.1**（`$PSEdition -eq 'Desktop'`），且无法改用 `pwsh`。
> **有 pwsh：** 不要用这份。包一层 `rtk pwsh -NoProfile -File`，改跟 `windows-agent-basics.md`。
> **禁止：** 把这份的 `powershell.exe` / 禁止 `&&` 规则带进 pwsh 会话。

## RTK

- Prefix **every** shell/terminal command with `rtk` when this environment uses RTK. Do not assume `rtk` exists in plain Claude Code or Codex installs without hooks/rules.
- In command chains, prefix **every** command.
- **Noisy builds** — prefer `rtk err <command>`: Gradle, gradlew, CMake, ninja, and similar verbose build/test output.
- Hooks that auto-rewrite commands are a fallback only; still write `rtk` explicitly for every command, including git/gradlew/cargo/rg and hook-skipped commands such as cmake, ninja, npm, and pwsh.
- **`rtk` only wraps external executables, not PowerShell cmdlets.** The first token after `rtk` is resolved against `PATH` (e.g. `pwsh.exe`, `cmd.exe`, `git.exe`). Writing `rtk Get-Content ...` or `rtk Select-String ...` fails with "Binary not found on PATH". To run a cmdlet, always use `rtk powershell -NoProfile -Command/-File ...` (or `rtk pwsh ...`).
- **`rtk` itself re-tokenizes its arguments, not just bash.** After `rtk` resolves the first token to an exe on `PATH`, it splits the remaining args on whitespace and strips quotes before passing them to that exe. Any PowerShell `-Command` string that contains internal `"`, `'`, or a `|` operator (e.g. `Select-String -Pattern "x y" | Measure-Object`) will be mangled: the inner quotes vanish, and the part after `|` is treated as a separate shell command. Rule of thumb:
  - For any non-trivial PowerShell command (2+ args, has `|`, or has internal quotes), write a `.ps1` and invoke with `rtk pwsh -NoProfile -File .\script.ps1`.
  - For a simple pattern search, skip PowerShell entirely and use `rtk rg -e PATTERN path` (safe under `rtk` because there is nothing for it to re-tokenize inside `rg`).
  - Never pack multi-token PowerShell pipelines into a single `-Command` string under `rtk`.
- **PowerShell `$` is fragile through outer wrappers** (`rtk`, `cmd /c "..."`, JSON shell tool). Before PowerShell runs, an outer layer may strip or rewrite `$variable`, `$_`, and especially `$env:NAME`; e.g. `$env:USERPROFILE` becomes empty or `:USERPROFILE`.
- **When `rtk` invokes PowerShell through bash, the outer layer is bash, not PowerShell.** In `rtk powershell -NoProfile -Command "..."`, bash sees the outer double quotes and expands every `$var`; inner single quotes do NOT protect against this. Fixes in priority order:
  1. **Escape the leading `$`**: `rtk powershell -NoProfile -Command "\$path='C:\...'; ..."`; bash does not expand `\$`, so PowerShell receives the literal string.
  2. **Use a `.ps1` with `-File`**: skips `-Command` string parsing entirely; preferred for any command with 2+ `;` or inline script blocks.
  3. **For a simple one-liner only, single-quote the whole `-Command` argument**: `rtk powershell -NoProfile -Command '... $_.LineNumber ...'`. This works because bash does not expand `$` inside single quotes. Do not use this for complex commands; write a `.ps1`.
  4. **Use an env-var placeholder**: `export LOG_PATH=...` then `\$env:LOG_PATH` inside the command (still needs `\$` to survive bash).
- **Never use outer double quotes around a PowerShell `-Command` that contains unescaped `$` variables.** This includes `$p`, `$patterns`, `$_`, and `$env:NAME`: `rtk powershell -NoProfile -Command "... $_.LineNumber ..."` is unsafe because bash may consume `$` before PowerShell runs.
- **Do not put unescaped `$env:` inside quoted outer strings.** Same rule for any inline PowerShell passed through `rtk cmd /c "..."` or chained commands. The escaped form `\$env:NAME` is only acceptable when an outer bash layer must pass a literal `$env:NAME` to PowerShell.
- **Do not pack complex PowerShell into one line.** If a command has more than two `;`-separated statements, or includes inline `ForEach-Object { ... }` / `Where-Object { ... }` / nested `foreach ($x in $y) { ... }` script blocks, write a small `.ps1` and run it with `pwsh -NoProfile -File .\script.ps1` (or `rtk pwsh ...` only in `rtk` environments).
- **PowerShell 5.1 does not support `&&` / `||`.** Chain with `;` and check `$LASTEXITCODE`, or write a `.ps1`.
- **PowerShell here-string must end with a standalone `"@` or `'@` line.** Never use `""` as the closer; that causes `MissingEndCurlyBrace` / ParserError. For embedded bash or multiline remote scripts, prefer a single-quoted here-string (`@' ... '@`) and fill variables with `-f`.
- **Treat `$_` inside inline pipeline script blocks as highest risk.** In `ForEach-Object { ... }` / `Where-Object { ... }`, prefer `param($item)` or a named `foreach ($item in $items)` loop. For nested blocks, write a `.ps1`.
- **For non-ASCII PowerShell paths, avoid fragile outer quoting.** Prefer `[Environment]::GetEnvironmentVariable(...)`, pass the path into a `.ps1`, or use a single-quoted literal.
- **PowerShell path literals should prefer single quotes or forward slashes.** Use `'C:\Users\...'` or `C:/Users/...` instead of `"C:\Users\..."` when a command passes through wrappers.
- **When PowerShell quoting or pipeline behavior fails mysteriously, fall back to `rg`.** Prefer `rg -n PATTERN path` for line numbers and context; avoid stacking extra shell processing such as `rg | head | awk`.
- **For log searches inside a line-number window, slice first, then search.** Use `Get-Content -Path $p | Select-Object -Skip $start -First $count` before matching, or use `rg -n PATTERN path`. Avoid fragile `Select-String` pipelines with repeated `-First` / `-Last` trimming.
- **Prefer these instead of `$env:` in one-liners:**
  - Known paths as literals: `C:\Users\...`
  - Bracket form (no leading `$`): `[Environment]::GetEnvironmentVariable('USERPROFILE')`
  - Multi-step logic -> write a small `.ps1`, then `pwsh -NoProfile -File .\script.ps1` (or `rtk pwsh ...` only in `rtk` environments)
  - Loops -> named variables: `foreach ($item in $items) { $item.Name }`, never `$_` in nested inline commands
- For deterministic enforcement, install a `PreToolUse` / `beforeShellExecution` hook that blocks the high-risk PowerShell shapes above before shell execution.
- **Text encoding (agent-authored files & outbound payloads):**
  - Chinese text, subtitles, prompts, docs, notifications, comments, ONES notes, webhook bodies: **UTF-8**.
  - **JSON / YAML / `.json` / MCP config / tool config / HTTP JSON body: UTF-8 without BOM.** Many parsers reject `EF BB BF` at file start; wrong encoding also produces mojibake in WeCom/ONES/UIs.
  - **Never rely on default encoding for JSON or Chinese-bearing payloads:**
    - `ConvertTo-Json` may serialize JSON, but its output must be written or sent with explicit UTF-8 encoding.
    - Do not use `Set-Content` / `Out-File` / `>` / `>>` defaults for `.json` / webhook payloads.
    - Do not POST an in-memory Chinese JSON string unless `Content-Type` explicitly includes `charset=utf-8`.
  - **Preferred approaches:**
    - Prefer editor `Write` / search-replace for JSON files.
    - Or Node/Python: `JSON.stringify` / `json.dumps` → write UTF-8 no BOM → POST file bytes (`node script.js`, `fetch`, `curl --data-binary @file`).
    - If PowerShell must write JSON: use `[System.IO.File]::WriteAllText($p, $json, [System.Text.UTF8Encoding]::new($false))` (or pwsh `utf8NoBOM`). For an in-memory POST, explicitly use `Content-Type: application/json; charset=utf-8`; otherwise POST verified UTF-8 no-BOM file bytes.
  - After writing JSON, verify no BOM: first bytes must **not** be `EF BB BF`.
  - Same rule applies to all outbound payloads and files (HTTP bodies, test reports, notifications, API notes), not only WeCom.
- When writing `.bat` or `.cmd` scripts, save them with Windows CRLF line endings, not LF-only.
- For large model downloads, prefer resumable/ranged downloads, conservative chunk sizes, and file verification. Do not repeatedly restart large downloads from zero.
- Do not write API keys or secrets into `config.yaml`, repos, rule files, or docs. Use environment variables or the tool's secret mechanism.
