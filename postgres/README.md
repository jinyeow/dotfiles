# postgres

Config for the PostgreSQL interactive terminal (`psql`).

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| PostgreSQL client | Provides `psql` | `winget install PostgreSQL.PostgreSQL` / system package manager |

## Files

| File | Installed as | Notes |
|---|---|---|
| `psqlrc` | `~/.psqlrc` | Loaded by psql on startup |

## Settings

| Setting | Effect |
|---|---|
| Custom `PROMPT1` | Shows host, port, user, database, and transaction status |
| `COMP_KEYWORD_CASE upper` | Tab-completes SQL keywords in UPPERCASE |
| `\x auto` | Switches between column/row display based on terminal width |
| `\pset null '[NULL]'` | Shows `[NULL]` instead of blank for null values |
| `\timing` | Prints query execution time after every result |
| `HISTSIZE 2000` | Keeps 2000 entries in psql history |
| `:version` | Shortcut variable: `SELECT version();` |
| `:extensions` | Shortcut variable: `SELECT * FROM pg_available_extensions;` |

## Install

```sh
./setup.ps1 -Module postgres   # Windows  (not yet in setup.ps1)
./setup.sh  -m postgres        # Linux / WSL  (not yet in setup.sh)
```

> Not yet wired into the setup scripts. Install manually:
> ```sh
> ln -sf "$(pwd)/postgres/psqlrc" ~/.psqlrc        # Linux
> copy postgres\psqlrc $env:USERPROFILE\.psqlrc     # Windows
> ```
