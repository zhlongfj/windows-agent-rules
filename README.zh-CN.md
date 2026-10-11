# Windows Agent Rules

[English](README.md)

给 **Cursor / Claude Code / Codex** 用的 Windows Agent 规则 + MSI PowerShell 7 安装 + Shell 安全 hook。

## 先看这段：这仓库到底强在哪

网上很多「Windows Agent 技巧」只是贴一段 markdown 规则。模型照样掉进 **Windows PowerShell 5.1**，`&&` 报错、同一条命令反复重试、白烧 token。中文路径和 `ConvertTo-Json` + `Set-Content` 还会悄悄写出带 **BOM / 乱码** 的 JSON，webhook、ONES、企微直接拒收。

本仓库不是「再贴一份规则」，而是 **三层一起上**：

| 层 | 做什么 |
|---|---|
| **规则** | 软指导：默认跟 pwsh 7、安全编码、别混 basics + p5 |
| **安装** | 硬布置：装 **MSI** 版 `pwsh`（不是商店 MSIX），并把目录放到 **PATH 最前** |
| **Hook** | 硬兜底：执行前拦高风险 `-Command` 形态和错误编码的 JSON 写法 |

**配好之后你通常能感到：**

- 少掉到 PS 5.1（Agent / 沙箱 spawn 商店 `pwsh` 失败的情况变少）
- 少中文 JSON 乱码 / BOM，webhook 等少拒收
- Agent 少反复试错 → **少浪费 token、少返工**
- MSI 路径 + PATH 顺序 + hook 是**硬护栏**，不是指望模型自觉

省 token 靠的是 **少失败、少刷失败日志**，不是压缩模型输出。

## 适合谁

- Windows 上长期用 Cursor / Claude Code / Codex 写代码的人
- 经常被 PowerShell 报错、中文路径/JSON 乱码折磨的人
- 想把同一套规则交给「新电脑上的 AI」自动布置的人

**不适合：** 纯 Linux/macOS；或不想装 PowerShell 7、坚持只用 5.1 的环境（那种只看 `rules/windows-agent-basics-p5.md`）。

---

## 怎么使用（最短路径）

### 1. Clone 后跑一键脚本

管理员或普通终端均可（MSI 安装失败时，再开**管理员**终端重跑）：

```powershell
cd path\to\windows-agent-rules
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

脚本会：

- 安装 MSI 版 pwsh（**不是**商店 MSIX）
- 把 `PowerShell\7` 挪到 PATH 最前
- 复制 hook 到 `%USERPROFILE%\.agents\hooks\`
- **打印**接下来要合并的配置（**不会**自动改你的 `settings.json` / `config.toml`）

### 2. 合并配置（有哪个工具配哪个）

| 步骤 | 谁做 | 说明 |
|---|---|---|
| 合并 Cursor / Claude / Codex 的 JSON、TOML、hooks | **AI 可代劳**，或自己粘 | 见 `examples/`；没有的工具直接跳过 |
| 粘贴 Cursor **User Rules** | **通常要人粘** | Settings → Rules → User Rules，贴 `rules/windows-agent-basics.md` **全文**（不支持 `@` 导入本目录） |
| Claude / Codex 的 `AGENTS.md` | AI 可代劳 | 用 `examples/AGENTS.snippet.md`，把 `REPO` 换成本仓库绝对路径（正斜杠） |
| 完全退出再开客户端 | **人** | Reload **不够**，要 Quit |

`setup.ps1` 结束时会打印本机的 `HOOK_PATH`（hook 文件完整路径）和 `REPO`，按提示替换示例里的占位符即可。

### 3. 验证

```powershell
powershell -NoProfile -File .\scripts\verify-setup.ps1
```

- **PASS**：该项 OK
- **SKIP**：对应工具/配置不存在（没装 Cursor/Claude/Codex 很正常）
- **FAIL**：工具已装但配错了

期望至少：`MSI pwsh exists` / `runs 7 Core` / `where pwsh first is MSI` / `hook copied` 为 PASS。

Agent **新对话**里再确认宿主：

```powershell
$PSVersionTable.PSVersion
[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
```

Major ≥ 7 且路径含 `Program Files\PowerShell\7\pwsh.exe` 才算切过去。旧对话可能仍是 5.1。

---

## 交给 AI 自动配 vs 仍需人工

把本目录丢给新电脑上的 AI，让它跑 `setup.ps1` + 合并 `examples/`：

| 可自动 | 通常仍要人确认 |
|---|---|
| 装 MSI pwsh、PATH 置顶、复制 hook | **Cursor User Rules** 粘贴全文 |
| 合并已安装工具的 settings / hooks / Codex `shell_path` | **完全退出**再开 Cursor / Claude / Codex |
| 跑 `verify-setup.ps1`；没装的工具 **SKIP** | 首次 winget MSI 权限不够时，可能要管理员重跑 |
| 写/更新 `AGENTS.md` 引用 basics | 不要同时 always-on basics + p5 |

---

## 规则怎么选

| 文件 | 何时 |
|---|---|
| `rules/windows-agent-basics.md` | **默认。** 命令跑在 pwsh 7+，或已用 `pwsh` / `rtk pwsh` 包住 |
| `rules/windows-agent-basics-p5.md` | **仅 fallback。** 真的停在 5.1，且 pwsh 不存在或调用失败 |

**不要**两份全文都贴进 always-on。混载会教模型写 `powershell.exe`、禁止 `&&`，和 pwsh 冲突。

Cursor Agent 有时仍会忽略 `defaultProfile`、宿主停在 5.1：有 pwsh 时 **先包** `pwsh -NoProfile -File script.ps1`，继续跟 basics，不要整段改用 p5。

---

## FAQ

### 为什么必须 MSI，不要商店包？

从 PowerShell 7.6 起，`winget install Microsoft.PowerShell` **默认装 MSIX**（`WindowsApps` 别名）。Agent / 沙箱经常 spawn 失败 → 回落 5.1。

要的是：

```text
C:\Program Files\PowerShell\7\pwsh.exe
```

```powershell
# 本仓库脚本（已装则跳过；同版本商店包会 --force 再装 MSI）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-pwsh.ps1

# 或手工（管理员）
winget install --id Microsoft.PowerShell --source winget --installer-type wix
```

若 winget 说「已安装、无升级」：商店 MSIX 与 MSI 是**同一包 ID + 同一版本**。不要卸、不要手删 `WindowsApps\pwsh.exe`。加 `--force` 再装 WiX/MSI，然后：

```powershell
powershell -NoProfile -File .\scripts\path-pwsh-first.ps1
```

### basics 和 p5 能一起开吗？

不能 always-on 混用。默认只挂 basics；只有确认没有 pwsh 时才临时跟 p5。

### 中文乱码 / JSON 被拒？

- JSON / HTTP body：**UTF-8 no BOM**（文件头不能是 `EF BB BF`）
- 不要用 `ConvertTo-Json` + `Set-Content`/`Out-File`/`>` 默认编码写中文 JSON
- 优先：编辑器写入、Node `JSON.stringify`、Python `json.dumps`，再 `curl --data-binary @file`
- hook 会拦一批高风险写法；规则是软指导，hook 是硬兜底

### 没装某个 AI 工具怎么办？

跳过即可。`verify-setup.ps1` 对缺的配置会 **SKIP**，不算失败。

### Hook 怎么挂？

`setup.ps1` 已复制 hook。把 `examples/*-hooks.json` 里的 **`HOOK_PATH`** 换成打印出的**完整 .mjs 路径**（正斜杠），合并进：

| 工具 | 文件 |
|---|---|
| Cursor | `%USERPROFILE%\.cursor\hooks.json` |
| Claude | `%USERPROFILE%\.claude\settings.json` → `hooks` |
| Codex | `%USERPROFILE%\.codex\hooks.json` |

---

## 三端 shell 配置摘要

路径一律钉 MSI，**不要**钉 `...\WindowsApps\pwsh.exe`。细节见 `examples/README.md`。

| 工具 | 合并 |
|---|---|
| Cursor | `examples/cursor-terminal-settings.json` → `%APPDATA%\Cursor\User\settings.json` |
| Claude | `examples/claude-settings.shell.json` → `%USERPROFILE%\.claude\settings.json`（`defaultShell: "powershell"` 是工具名，不是 `powershell.exe`） |
| Codex | `scripts/emit-codex-shell-path.ps1` 输出 → `%USERPROFILE%\.codex\config.toml` 的 `[windows] shell_path` |

---

## 仓库内容

| 路径 | 用途 |
|---|---|
| `rules/windows-agent-basics.md` | pwsh 7 主规则 |
| `rules/windows-agent-basics-p5.md` | PS 5.1 fallback |
| `hooks/windows-powershell-safety.mjs` | Shell 硬拦 |
| `examples/` | 配置片段（含 `AGENTS.snippet.md`） |
| `scripts/setup.ps1` | clone 后一键：安装 + PATH + 复制 hook |
| `scripts/install-pwsh.ps1` | 只装 MSI |
| `scripts/path-pwsh-first.ps1` | PATH 把 MSI 目录置顶 |
| `scripts/verify-setup.ps1` | 检测 MSI / PATH / 本机三端配置 |
| `scripts/emit-codex-shell-path.ps1` | 输出 Codex `shell_path` |

## 不要提交

- API key、token、`.env`
- 含真实路径/用户名的本地 `settings.local.json`
- 个人 `~/.claude/settings.json` 等（本仓库只提供 `examples/` 片段）

## License

MIT — [LICENSE](LICENSE)