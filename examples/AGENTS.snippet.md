# Paste into %USERPROFILE%\AGENTS.md (Claude Code + Codex)

Replace `REPO` with this clone's absolute path. Use forward slashes.

Do **not** `@`-import `windows-agent-basics-p5.md`. Mixing both files teaches the model to call `powershell.exe` and forbid `&&`.

```markdown
## Shell rule routing

- Default: PowerShell 7 (`pwsh`). Follow `windows-agent-basics.md` only. Prefer `pwsh` / `rtk pwsh`. Do not start `powershell.exe` when `pwsh` exists.
- Fallback only: if this command actually runs in Windows PowerShell 5.1 (`$PSEdition -eq 'Desktop'` or `PSVersion.Major -lt 7`) **and** wrapping with `pwsh` failed or `pwsh` is missing, read `REPO/rules/windows-agent-basics-p5.md` and follow that file only. Do not mix the two files in one command.
- Cursor Agent on Windows often still hosts `powershell.exe` 5.1 even when pwsh is installed (product ignores `defaultProfile`). Wrap: `rtk pwsh -NoProfile -File .\script.ps1` (or `rtk pwsh -NoProfile -Command '...'`), then follow `windows-agent-basics.md`.

@REPO/rules/windows-agent-basics.md
```

Claude Code: keep `%USERPROFILE%\.claude\CLAUDE.md` importing `AGENTS.md` (already the usual pattern).

Codex: keep `%USERPROFILE%\.codex\AGENTS.md` importing `AGENTS.md`.
