# VSCode

## Sync strategy

**Settings Sync is the primary sync mechanism** — VSCode's built-in Settings Sync pushes and pulls settings automatically across machines via your Microsoft/GitHub account. The `settings.json` in this directory is a reference snapshot only; it is not copied or linked by the installer.

To update the snapshot after making changes in VSCode, copy `%APPDATA%\Code\User\settings.json` into this directory and commit.

## Machine-specific settings

Some settings are excluded from Settings Sync via `settingsSync.ignoredSettings` and must be configured locally on each machine:

| Setting | Why machine-specific |
|---|---|
| `vscode-neovim.neovimExecutablePaths.win32` | Neovim install path varies |
| `powershell.powerShellAdditionalExePaths` | PS install path varies |
| `dotnetAcquisitionExtension.existingDotnetPath` | .NET install path varies |
| `dev.containers.dockerPath` | Docker vs Podman varies per machine |
| `mssql.connections` | Work-specific DB connections, sensitive |
| `mssql.connectionGroups` | Companion to mssql.connections |
| `github-actions.use-enterprise` | Enterprise vs github.com varies per machine |
| `azdoPullRequests.orgUrl` | Work-specific Azure DevOps URL |
| `azdoPullRequests.patToken` | Sensitive credential |
| `azdoPullRequests.projectName` | Work-specific project |

## Notable settings

- **Theme**: Catppuccin Macchiato (dark) / Catppuccin Latte (light), auto-detected from OS theme via `window.autoDetectColorScheme`
- **Vim**: vscode-neovim (`asvetliakov.vscode-neovim`) is the primary Vim integration. VSCodeVim (`vim.*`) settings are kept as a fallback for machines without Neovim installed — disable VSCodeVim on machines where vscode-neovim is active
- **Formatter**: EditorConfig as default; language-specific overrides for JSON, YAML, Azure Pipelines, Docker Compose, JavaScript
- **Line length**: 120 columns (rulers + wordWrapColumn)
- **Font**: CommitMono Nerd Font Mono with ligatures (falls back to Fira Code, then monospace)
