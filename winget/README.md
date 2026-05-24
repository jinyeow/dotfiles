# winget

Curated package list for bootstrapping a new Windows machine. Covers dev tools,
editors, terminal utilities, languages, cloud/Azure tooling, containers, and
general utilities. Excludes games, hardware software, system runtimes, and
work-specific tools.

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
- **Games** — Steam, Epic, Battle.net, etc.
- **Hardware software** — ASUS Armoury, Logitech G HUB, AMD Software, etc.
- **Work-specific tools** — Azure VPN Client, Cosmos DB Emulator, Webex, etc.
- **.NET / VC++ runtimes** — installed automatically as dependencies
