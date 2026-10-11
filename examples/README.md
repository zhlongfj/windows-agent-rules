# Example snippets

Copy into local config. After `scripts/setup.ps1`, replace placeholders:

- **`HOOK_PATH`** → full path to the hook file (forward slashes), e.g.
  `C:/Users/<you>/.agents/hooks/windows-powershell-safety.mjs`
  Example JSON uses `"node HOOK_PATH"` (file path, **not** a directory).
- **`REPO`** → this clone's absolute path (forward slashes) in `AGENTS.snippet.md`.

| File | Merge into |
|---|---|
| `AGENTS.snippet.md` | `%USERPROFILE%\AGENTS.md` (Claude / Codex). Do **not** `@`-import p5 |
| `cursor-terminal-settings.json` | `%APPDATA%\Cursor\User\settings.json` (pin MSI; disable Windows PowerShell profile) |
| `cursor-hooks.json` | `%USERPROFILE%\.cursor\hooks.json` |
| `claude-settings.shell.json` | `%USERPROFILE%\.claude\settings.json` (env + defaultShell) |
| `claude-settings.hooks.json` | `%USERPROFILE%\.claude\settings.json` → `hooks` |
| `codex-config.shell.toml` | `%USERPROFILE%\.codex\config.toml` → `[windows]` |
| `codex-hooks.json` | `%USERPROFILE%\.codex\hooks.json` |

Cursor User Rules: paste the full text of `rules/windows-agent-basics.md`, not the p5 file.

Do not pin `...\WindowsApps\pwsh.exe`.