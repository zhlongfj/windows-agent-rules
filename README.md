# Windows Agent Rules

[中文](README.zh-CN.md)

Windows Agent rules + MSI PowerShell 7 setup + shell safety hook for **Cursor / Claude Code / Codex**.

## Why this exists (read this first)

Most “Windows agent tips” are just markdown rules. Agents still drop into **Windows PowerShell 5.1**, hit `&&` errors, retry the same broken command, and burn tokens. Chinese paths and `ConvertTo-Json` + `Set-Content` quietly write **BOM / mojibake** JSON that webhooks and APIs reject.

This repo is different because it combines **three layers**:

| Layer | What it does |
|---|---|
| **Rules** | Soft guidance: prefer `pwsh` 7, safe encoding, don’t mix basics + p5 |
| **Install** | Hard setup: install **MSI** `pwsh` (not Store MSIX) and put it **first on PATH** |
| **Hook** | Hard guardrail: block high-risk `-Command` shapes and bad JSON/encoding one-liners before they run |

**After a correct setup you should see:**

- Fewer silent fallbacks to PS 5.1 (Agent / sandbox spawn of Store `pwsh` fails less often)
- Fewer Chinese JSON mojibake / BOM rejects from webhooks, ONES, WeCom, etc.
- Less agent retry loops → less wasted tokens and less rework
- MSI path + PATH order + hook as **hard guardrails**, not hope-the-model-listens

Saving tokens comes from **fewer failed attempts and less noisy failure logs**, not from compressing model output.

## Who it is for

- People who use Cursor / Claude Code / Codex on Windows every day
- Anyone tired of PowerShell errors and Chinese path / JSON encoding pain
- Anyone who wants to hand this folder to an AI on a **new PC** and get most of the setup done automatically

**Not for:** pure Linux/macOS, or environments that refuse PowerShell 7 and insist on 5.1 only (use `rules/windows-agent-basics-p5.md` alone).

---

## Quick start

### 1. Clone and run setup

Admin or normal terminal is fine (if MSI install fails, rerun in an **elevated** prompt):

```powershell
cd path\to\windows-agent-rules
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1
```

The script will:

- Install MSI PowerShell 7 (**not** Store MSIX)
- Move `C:\Program Files\PowerShell\7` to the front of PATH
- Copy the hook to `%USERPROFILE%\.agents\hooks\`
- **Print** merge steps (it does **not** rewrite your `settings.json` / `config.toml`)

### 2. Merge configs (only tools you have)

| Step | Who | Notes |
|---|---|---|
| Merge Cursor / Claude / Codex JSON, TOML, hooks | **AI can do it**, or paste yourself | See `examples/`; skip missing tools |
| Paste Cursor **User Rules** | **Usually manual** | Settings → Rules → User Rules: paste **full text** of `rules/windows-agent-basics.md` (no `@` import of this folder) |
| Claude / Codex `AGENTS.md` | AI can do it | Use `examples/AGENTS.snippet.md`; replace `REPO` with this clone’s absolute path (forward slashes) |
| Fully quit and reopen clients | **You** | Reload is **not** enough — Quit |

`setup.ps1` prints your machine’s `HOOK_PATH` and `REPO`; replace placeholders in the examples.

### 3. Verify

```powershell
powershell -NoProfile -File .\scripts\verify-setup.ps1
```

- **PASS** — OK  
- **SKIP** — tool/config absent (normal if Cursor/Claude/Codex isn’t installed)  
- **FAIL** — tool is installed but misconfigured  

Expect at least: `MSI pwsh exists` / `runs 7 Core` / `where pwsh first is MSI` / `hook copied` = PASS.

In a **new** Agent chat, confirm the host:

```powershell
$PSVersionTable.PSVersion
[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
```

Major ≥ 7 and path contains `Program Files\PowerShell\7\pwsh.exe`. Old chats may still be 5.1.

---

## AI auto-setup vs still human

Hand this folder to an AI on a new PC; ask it to run `setup.ps1` and merge `examples/`:

| Can automate | Usually still needs a human |
|---|---|
| Install MSI pwsh, PATH first, copy hook | Paste **Cursor User Rules** in full |
| Merge settings / hooks / Codex `shell_path` for installed tools | **Fully quit** Cursor / Claude / Codex |
| Run `verify-setup.ps1`; missing tools **SKIP** | Elevate and rerun if first MSI install lacks permission |
| Write/update `AGENTS.md` to reference basics | Do **not** always-on both basics and p5 |

---

## Which rule file

| File | When |
|---|---|
| `rules/windows-agent-basics.md` | **Default.** Commands run on pwsh 7+, or wrapped with `pwsh` / `rtk pwsh` |
| `rules/windows-agent-basics-p5.md` | **Fallback only.** Truly stuck on 5.1 and pwsh missing or failed |

**Do not** paste both full texts into always-on rules. Mixing teaches the model to start `powershell.exe` and forbid `&&`, which fights pwsh.

Cursor Agent sometimes ignores `defaultProfile` and stays on 5.1: if pwsh exists, **wrap** with `pwsh -NoProfile -File script.ps1` and keep following basics — don’t switch the whole session to p5.

---

## FAQ

### Why MSI, not the Store package?

From PowerShell 7.6 onward, `winget install Microsoft.PowerShell` **defaults to MSIX** (`WindowsApps` alias). Agents / sandboxes often fail to spawn it → fall back to 5.1.

You want:

```text
C:\Program Files\PowerShell\7\pwsh.exe
```

```powershell
# This repo (skips if already present; force-reinstalls MSI over same-version Store package)
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-pwsh.ps1

# Or manually (admin)
winget install --id Microsoft.PowerShell --source winget --installer-type wix
```

If winget says “already installed, no upgrade”: Store MSIX and MSI share the **same package ID + version**. Don’t uninstall and don’t hand-delete `WindowsApps\pwsh.exe`. Use `--force` with WiX/MSI, then:

```powershell
powershell -NoProfile -File .\scripts\path-pwsh-first.ps1
```

### Can basics and p5 both be always-on?

No. Default to basics only; use p5 temporarily only when you confirm pwsh is unavailable.

### Chinese mojibake / rejected JSON?

- JSON / HTTP bodies: **UTF-8 no BOM** (file must not start with `EF BB BF`)
- Don’t write Chinese JSON with `ConvertTo-Json` + `Set-Content` / `Out-File` / `>` defaults
- Prefer: editor write, Node `JSON.stringify`, Python `json.dumps`, then `curl --data-binary @file`
- The hook blocks many high-risk patterns; rules guide, the hook enforces

### Missing an AI tool?

Skip it. `verify-setup.ps1` **SKIP**s absent configs — that is not failure.

### How do I wire the hook?

`setup.ps1` already copies it. In `examples/*-hooks.json`, replace **`HOOK_PATH`** with the printed **full .mjs path** (forward slashes), then merge into:

| Tool | File |
|---|---|
| Cursor | `%USERPROFILE%\.cursor\hooks.json` |
| Claude | `%USERPROFILE%\.claude\settings.json` → `hooks` |
| Codex | `%USERPROFILE%\.codex\hooks.json` |

---

## Shell config cheat sheet

Always pin the MSI path — **never** `...\WindowsApps\pwsh.exe`. Details in `examples/README.md`.

| Tool | Merge |
|---|---|
| Cursor | `examples/cursor-terminal-settings.json` → `%APPDATA%\Cursor\User\settings.json` |
| Claude | `examples/claude-settings.shell.json` → `%USERPROFILE%\.claude\settings.json` (`defaultShell: "powershell"` is the tool name, not `powershell.exe`) |
| Codex | `scripts/emit-codex-shell-path.ps1` output → `%USERPROFILE%\.codex\config.toml` `[windows] shell_path` |

---

## Repository layout

| Path | Purpose |
|---|---|
| `rules/windows-agent-basics.md` | pwsh 7 primary rules |
| `rules/windows-agent-basics-p5.md` | PS 5.1 fallback |
| `hooks/windows-powershell-safety.mjs` | Shell hard block |
| `examples/` | Config snippets (incl. `AGENTS.snippet.md`) |
| `scripts/setup.ps1` | One-shot: install + PATH + copy hook |
| `scripts/install-pwsh.ps1` | MSI only |
| `scripts/path-pwsh-first.ps1` | Put MSI dir first on PATH |
| `scripts/verify-setup.ps1` | Check MSI / PATH / local tool configs |
| `scripts/emit-codex-shell-path.ps1` | Print Codex `shell_path` |

## Do not commit

- API keys, tokens, `.env`
- Local `settings.local.json` with real paths/usernames
- Personal `~/.claude/settings.json` (this repo only ships `examples/` snippets)

## License

MIT — [LICENSE](LICENSE)