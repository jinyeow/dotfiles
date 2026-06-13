# winget

Curated package list for bootstrapping a new Windows machine. Covers dev tools,
editors, terminal utilities, languages, cloud/Azure tooling, containers, and
general utilities, plus a few daily-driver personal apps (communication, cloud
sync). Excludes games, hardware software, system runtimes, and work-specific
tools.

`packages.ps1` and `packages.json` are kept **identical** — the same package set
in both. The `.ps1` installs them; the `.json` is for `winget import`.

## Usage

### PowerShell script (recommended)

```powershell
# Preview what would be installed
.\winget\packages.ps1 -DryRun

# Install everything
.\winget\packages.ps1
```

Skips packages already installed. Grouped by category for easy editing.

### winget import (JSON)

```powershell
winget import -i winget\packages.json --ignore-unavailable
```

The `--ignore-unavailable` flag skips any packages not found in the winget
source without failing the whole import.

## Keeping it up to date

When you install a new tool you want on future machines, add it to both files:

- `packages.ps1` — add an `Install-Package '<id>'` line in the right category
- `packages.json` — add `{ "PackageIdentifier": "<id>" }` to the Packages array (alphabetical)

To find the correct winget ID for a tool:

```powershell
winget search <tool-name>
```

## What's not included

- **MSIX-only apps** (Ditto, DevToys, EarTrumpet) — install from the Microsoft Store
- **Games & launchers** — Steam, Epic, Battle.net, Riot, etc.
- **Hardware software** — ASUS Armoury, Logitech G HUB, AMD Software, etc.
- **Work-specific tools** — Azure VPN Client, Cosmos DB / Storage Emulator, Webex, Teams, etc.
- **.NET / VC++ runtimes** — installed automatically as dependencies
- **Duplicate SDK versions** — keep only the latest of a given SDK (e.g. .NET SDK 10, not 7/8/9)
- **Secondary browsers** — beyond the curated Firefox + Zen (no Chrome, Edge, etc.)
- **Standalone media players & taggers** — Jellyfin, Sonixd, Mp3tag, etc.
- **Antivirus / security suites** — Bitdefender, etc. (use the OS default)
- **Tools that duplicate a curated CLI** — e.g. Git GUIs (Git Extensions) when lazygit/jj are already in
