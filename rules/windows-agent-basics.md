# Windows Agent Basics

> **适用：** 当前命令实际跑在 **PowerShell 7+ (`pwsh`)**，或已用 `pwsh` / `rtk pwsh` 包住。
> **默认走这份。** Cursor / Claude / Codex 应优先 `pwsh`，不要主动调 `powershell.exe`。
> **仅当命令真的停在 Windows PowerShell 5.1**（`pwsh` 不存在或调用失败）：改用 `windows-agent-basics-p5.md`，两份不要混用。

## Shell 前提（PowerShell 7）

- 验证：`$PSVersionTable.PSVersion` ≥ 7，`$PSVersionTable.PSEdition` = `Core`。
- **直接 pwsh 里跑**（不经 RTK/bash 包装）：可用 `&&` / `||`；简单 cmdlet / 管道一行可跑。
- **Agent Shell 是否真走 pwsh**，取决于各工具的 shell 配置 + hook，**不是**只改 Windows Terminal 默认 profile 就自动生效。
- 仍优先 `rg` 搜文件/日志；复杂多步逻辑、嵌套 script block → 写 `.ps1`，用 `pwsh -NoProfile -File .\script.ps1`。

## RTK

- 本环境有 RTK 时：**每条**外部命令前缀 `rtk`；命令链里**每条**都要前缀。
- 噪声构建优先 `rtk err <command>`：Gradle、gradlew、CMake、ninja 等。
- Hook 自动改写是兜底；仍显式写 `rtk`（含 git、gradlew、cargo、rg、pwsh）。
- **`rtk` 只包 exe，不包 cmdlet。** `rtk Get-Content` 会失败 → 用 `rtk pwsh -NoProfile -File script.ps1` 或（简单时）`rtk pwsh -NoProfile -Command '...'`。
- **`rtk` 会 re-tokenize 参数**（空白拆分、去引号）。含 `|`、内嵌 `"`/`'`、或复杂 `-Command` → **写 `.ps1`**，不要赌 `-Command` 字符串。
- 简单搜索：跳过 PS，用 `rtk rg -e PATTERN path`。

## 经 RTK / bash / 外层包装时（仍严格）

- 外层可能吃掉 `$variable`、`$_`、`$env:NAME`（变成空或 `:USERPROFILE`）。
- `rtk pwsh -NoProfile -Command "..."` 若经 bash：双引号内 `$` 会被 bash 展开。
- 修复优先级：
  1. **`.ps1` + `-File`**（首选）
  2. 简单一行：整个 `-Command` 用**单引号**包起来
  3. 必须经 bash 传 `$`：`\$env:NAME`
  4. 或 `[Environment]::GetEnvironmentVariable('NAME')`（无 leading `$`）
- 禁止：双引号 `-Command` + 未转义 `$`；`-Command` 里 3+ 语句；`ForEach-Object { ... $_ ... }` 一行塞完。
- Here-string 结束行必须单独 `"@` 或 `'@`。
- 中文/非 ASCII 路径：放 `.ps1` 里用单引号字面量，或 `[Environment]::GetEnvironmentVariable(...)`。

## 直接 pwsh 时（可放松）

- `git status && git diff` 等链式命令 OK。
- 简单 `Get-ChildItem`、`Select-String` 管道 OK。
- **仍禁止/仍谨慎：**
  - `ConvertTo-Json` 默认写文件 / 默认 POST 中文 JSON
  - `Set-Content` / `Out-File` / `>` 写 `.json`（BOM/编码坑）
  - 深层嵌套 `ForEach-Object { ... }` 仍建议 `.ps1`

## Text encoding（agent 产出 & 出站 payload）

- 中文、文档、通知、ONES、webhook：**UTF-8**。
- **JSON / YAML / MCP / HTTP body：UTF-8 no BOM。** 文件头不能是 `EF BB BF`。
- **不要**依赖 PS 默认编码写 JSON：
  - 优先：编辑器 Write、Node `JSON.stringify`、Python `json.dumps` → UTF-8 no BOM → `curl --data-binary @file`
  - 必须 PS 写 JSON：`[System.IO.File]::WriteAllText($p, $json, [System.Text.UTF8Encoding]::new($false))` 或 pwsh `-Encoding utf8NoBOM`
  - POST 中文 JSON：`Content-Type: application/json; charset=utf-8`，或 POST 已验证的 UTF-8 文件字节
- 同上规则适用于所有出站文件（报告、通知、API note），不限企微。

## 其他

- 日志/代码搜索：优先 `rg -n PATTERN path`；窗口内搜索先 slice 再 match，或直接用 `rg`。
- `.bat` / `.cmd`：CRLF 行尾。
- 大文件下载：断点续传、分块、校验；不要从零反复重下。
- 密钥：不写进 config、规则、文档；用环境变量或工具 secret 机制。

## Hook（推荐配套）

- 硬拦高风险形状 + UTF-8 JSON：`hooks/windows-powershell-safety.mjs`
- 挂点：Cursor `beforeShellExecution` + Shell `preToolUse`；Claude `PreToolUse` matcher `Bash`；Codex `PreToolUse` matcher `Bash`
- 规则是软指导；hook 是硬兜底。两者一起用。
