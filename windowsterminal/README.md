# windowsterminal

Windows Terminal settings.

## Files

| File | Installed to |
|---|---|
| `settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |

## Notes

Installed via `Copy-Dotfile` (not a junction) because Windows Terminal writes
back to `settings.json` when you change settings in the UI. After making UI
changes you want to keep, copy the file back to the repo manually:

```powershell
Copy-Item "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" `
    "path\to\dotfiles\windowsterminal\settings.json"
```

## Install

```powershell
.\setup.ps1 -Module windowsterminal
```

Windows-only — skipped silently on Linux.
