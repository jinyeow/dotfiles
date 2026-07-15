# Azure Functions local development in Neovim

**Verdict: it's CLI + LSP + DAP, and it works — debugging included.** No Neovim
plugin earns its place. `roslyn.nvim` already covers the language server (a
Functions project is just a .NET console app), and the run/deploy loop is `func`
and `az` in a terminal. The only new piece is `netcoredbg` plus a `coreclr` block
in `dap.lua`.

**Nothing here is installed into the repo yet** — the `dap.lua` block below is a
proposal. But the *findings* are not speculation: the debugging path was spiked
end-to-end on this machine (2026-07-15) and breakpoints hit. Everything marked
"verified" was observed, not read.

## What's already here

| Piece | State |
|---|---|
| `func` (Core Tools) | **4.12.1**, already installed; `Microsoft.Azure.FunctionsCoreTools` already in `winget/packages.json` |
| .NET SDK / runtimes | SDK **10.0.302**; runtimes 8, 9, 10 present |
| `az`, `node` | installed (node via Volta — matters only because Azurite is an npm package) |
| `roslyn.nvim` | wired in `lua/config/lsp.lua` |
| `netcoredbg` | **installed during the spike** (`winget install -e --id Samsung.NetCoreDbg`, 3.1.3-1062). Not yet in `winget/packages.json` — add it if we adopt this. |
| Azurite | **installed during the spike** (`npm install -g azurite`) |
| `nvim-dap` | declared in `plugins.lua` + pinned in the lockfile, but **not actually installed on this machine** — see Open questions |

## 1. Language server — nothing to do

An isolated-worker Functions project is an ordinary console app (`.csproj` +
`Program.cs` + `host.json`). `roslyn.nvim` attaches to `cs` buffers already, so
completion, `gd`, and diagnostics work with **no change**. `host.json` /
`local.settings.json` are JSON, so `jsonls` + `schemastore.nvim` cover them
(schemastore's `host.json` filename match is unconfirmed — worth one check).

## 2. Local run loop

Azurite is required: `AzureWebJobsStorage` needs a real or emulated storage
account even for an HTTP-only app.

```powershell
npm install -g azurite
azurite --silent --location $env:TEMP\azurite    # listens on 10000/10001/10002
```

**The default `func` template does not run locally as scaffolded.** `func new`
emits a `Program.cs` calling `.UseAzureMonitorExporter()`, which throws
`System.InvalidOperationException: A connection string was not found` and kills the
worker on startup — with or without a debugger. The host then reports only a vague
`Exceeded language worker restart retry count`. Fix by adding an App Insights
connection string to `local.settings.json` (a dummy value is fine locally), or by
deleting the OpenTelemetry lines from `Program.cs`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://westus2-0.in.applicationinsights.azure.com/"
  }
}
```

`func init` scaffolds a `.gitignore` excluding `local.settings.json` (it can hold
secrets) and a `.vscode/extensions.json` — but **no `launch.json`**, so there's
nothing VS-Code-shaped to ignore.

```powershell
func init MyProj --worker-runtime dotnet-isolated --target-framework net10.0
func new --template "HTTP trigger" --name Ping --authlevel anonymous
func start                                   # endpoints print on :7071
```

Non-HTTP triggers fire locally via the admin endpoint, no live Azure service
([docs](https://learn.microsoft.com/azure/azure-functions/functions-run-local#run-a-local-function)):

```powershell
curl --request POST --data '{"input":"sample queue data"}' `
  -H "Content-Type:application/json" http://localhost:7071/admin/functions/QueueTrigger
```

## 3. Debugging — verified working

**Why netcoredbg and not Microsoft's own debugger (do not reverse).** Microsoft's
`vsdbg` is licence-locked to the VS family — *"You may only use the Microsoft .NET
Core Debugger (vsdbg) with Visual Studio Code, Visual Studio or Visual Studio for
Mac software to help you develop and test your applications"*
([vsdbg-LICENSE.txt](https://github.com/microsoft/vscode-cpptools/blob/main/RuntimeLicenses/vsdbg-LICENSE.txt);
Microsoft confirmed the reading in
[omnisharp-vscode#1431](https://github.com/OmniSharp/omnisharp-vscode/issues/1431#issuecomment-297578930)).
Neovim isn't on that list, so using vsdbg here would be a licence violation — and
it's enforced technically too, not just contractually: vsdbg requires a signing
handshake via the closed-source `vsda.node` that ships only inside VS Code
([nvim-dap#869](https://github.com/mfussenegger/nvim-dap/discussions/869)). A
2020–2023 relicensing request went nowhere
([dotnet/core#4788](https://github.com/dotnet/core/issues/4788)).
`Samsung/netcoredbg` is MIT, actively maintained (Samsung builds it for Tizen
.NET), and is what nvim-dap/Emacs setups standardise on. It is the correct **and
only legitimate** choice here.

**What netcoredbg gives up vs vsdbg.** Core debugging is at parity — line/
conditional/function breakpoints, step in/over/out, call stack, locals/watch, basic
evaluation, exception breakpoints, attach, threads
([features](https://github.com/Samsung/netcoredbg/wiki/Features)). The gaps, read
from its DAP capability declaration
([vscodeprotocol.cpp](https://github.com/Samsung/netcoredbg/blob/master/src/protocols/vscodeprotocol.cpp#L412-L435)):

| Feature | netcoredbg | Impact |
|---|---|---|
| Logpoints / tracepoints | ✗ | can't log without editing code |
| Hit-count breakpoints | ✗ | no "break on Nth pass" |
| Data breakpoints | ✗ | no "break when field changes" |
| Per-exception-type filters | ✗ (`supportsExceptionOptions` = false, "TODO") | coarser exception control |
| Hot Reload / Edit-and-Continue | Windows only ([#214](https://github.com/Samsung/netcoredbg/issues/214)) | — (fine here) |
| Method calls in watch expressions | reported broken ([#28](https://github.com/Samsung/netcoredbg/issues/28)) | weaker evaluator |
| Async stepping / exception stacks | rough ([#192](https://github.com/Samsung/netcoredbg/issues/192), [vimspector#293](https://github.com/puremourning/vimspector/issues/293)) | stepping over `await` can misbehave |
| Source Link, return-value inspection | **unknown** — undocumented either way | verify before relying on it |

None of this blocks the Functions loop (attach → breakpoint → inspect → continue),
which is exactly what the spike exercised.

**Spike result: breakpoints bind and hit, on both `net8.0` and `net10.0`.** The
reported Windows `0x80070057` `configurationDone` failure
([nvim-dap#1369](https://github.com/mfussenegger/nvim-dap/discussions/1369))
**did not reproduce** — the DAP handshake (`initialize` → `attach` →
`setBreakpoints` → `configurationDone`) returned clean, and execution paused inside
the function:

```
BREAKPOINT VERIFIED at line 20
STOPPED: reason=breakpoint
  frame[1] funcspike.Ping.Run()  Ping.cs:20
  frame[2] funcspike.DirectFunctionExecutor.<ExecuteAsync>d__3.MoveNext()  GeneratedFunctionExecutor.g.cs:38
```

The in-flight HTTP request genuinely blocked while paused and completed on
`continue`. Stack frames were inspectable.

Three things the docs get wrong or don't say, all found by running it:

**a. The worker does not pause, and does not print its PID.** The documented
`"Azure Functions .NET Worker (PID: …) initialized in debug mode. Waiting for
debugger to attach..."` message is **.NET-Framework-only** behaviour. On .NET 8/10
isolated the worker starts and serves immediately; `--dotnet-isolated-debug`
changed nothing observable. So there is no PID to read off the console — you must
find the worker yourself.

**b. `nvim-dap`'s `pick_process` cannot identify the worker on Windows.** Its
`get_processes()` shells out to `tasklist /nh /fo csv` and takes the **image name
only** (`"dotnet.exe"`) — on Linux it gets the full command line from `ps`, but on
Windows there's nothing to filter on. Verified in
[dap/utils.lua](https://github.com/mfussenegger/nvim-dap/blob/master/lua/dap/utils.lua).
Resolve the PID out-of-band instead — the worker's command line is distinctive
(`dotnet.exe <proj>\bin\output\<name>.dll --functions-worker-id …`).

**c. Source path separators are load-bearing — this is the big trap.** A
mixed-separator path (`C:\dir/sub/Ping.cs`) fails to match the path recorded in the
PDB. netcoredbg then reports `"The breakpoint will not currently be hit. No symbols
have been loaded for this document."`, `verified = false`, and the breakpoint
**silently never binds** — the function runs straight through. With native
backslashes the same breakpoint verified in ~1s. Normal editing on Windows gives
backslash buffer names (`shellslash` is off by default), so this mainly bites
paths built programmatically. *(Verified: mixed fails, backslash works. An
all-forward-slash path was not tested.)*

Proposed `dap.lua` addition, gated on the executable like the `dotnet` gate in
`lsp.lua`. **Assembled from verified parts, not tested as a unit:** the CIM query
was verified in PowerShell and the attach was verified in nvim-dap with a
hardcoded PID, but this Lua glue was not run end-to-end. `out:match('%d+')` takes
the first digit-run in stdout, which is fine only if pwsh prints nothing ahead of
it.

```lua
if vim.fn.executable('netcoredbg') == 1 then
  dap.adapters.coreclr = {
    type = 'executable',
    command = 'netcoredbg',
    args = { '--interpreter=vscode' },
  }

  -- nvim-dap's pick_process is useless here: on Windows it only sees image names
  -- via `tasklist`, so every dotnet.exe looks alike. Match on the command line.
  local function functions_worker_pid()
    local ps = [[Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" ]]
      .. [[| Where-Object { $_.CommandLine -like '*--functions-worker-id*' } ]]
      .. [[| Select-Object -First 1 -ExpandProperty ProcessId]]
    local out = vim.fn.system({ 'pwsh', '-NoProfile', '-NonInteractive', '-Command', ps })
    return tonumber(out:match('%d+')) or tonumber(vim.fn.input('Worker PID: '))
  end

  dap.configurations.cs = {
    {
      type = 'coreclr',
      name = 'attach — Functions worker',
      request = 'attach',
      processId = functions_worker_pid,
      justMyCode = false,
    },
  }
end
```

Loop: `azurite` → `func start` → attach → hit the endpoint.

Remaining gotchas: framework assemblies are Release builds, so stepping into them
is degraded (`justMyCode = false` above is what let us step into everything);
missing PDBs leave breakpoints pending
([netcoredbg docs](https://github.com/Samsung/netcoredbg/blob/master/docs/cli.md)).

## 4. Deploy

```powershell
az login
func azure functionapp publish <FunctionAppName>
```

Zip-deploy with a remote build; the app must already exist. Useful flags:
`--publish-local-settings`, `--slot`, `--no-build`
([docs](https://learn.microsoft.com/azure/azure-functions/functions-run-local#deploy-project-files)).

## 5. Target framework: use .NET 10 for both personal and work

**.NET 10 is both the latest stable *and* the conservative choice** — it's an LTS,
GA on Functions v4 isolated. The intuition that "work should lag to .NET 8" is
inverted here, because .NET 8 is nearly out of support:

| .NET | Release type | Functions v4 support ends |
|---|---|---|
| **10** | **LTS** | **Nov 14, 2028** |
| 9 | STS | Nov 10, 2026 |
| 8 | LTS | Nov 10, 2026 |

Both 8 and 9 expire in **~4 months** ([runtime versions
table](https://learn.microsoft.com/azure/azure-functions/functions-versions#languages)).
`func init --target-framework net8.0` says so itself: *".NET 8 will reach
end-of-life on November 10 2026 and will no longer be supported."*

**Doc inconsistency, resolved — .NET 10 is GA for hosting, not preview.** The
migration guides still say "(preview)", but three things in the current docs
settle it:

- The versions table lists .NET 10 with support level **GA**, end-of-support
  Nov 14 2028 ([functions-versions#languages](https://learn.microsoft.com/azure/azure-functions/functions-versions#languages)).
- The isolated-worker guide states *"Azure Functions doesn't currently work with any
  'Preview' or 'Go-live' .NET releases. See Supported versions for a list of
  generally available releases that you can use."* — and .NET 10 is in that table.
- Footnote **^5^** on `.NET 10` is **not** a preview qualifier; it reads *"You can't
  run .NET 10 apps on Linux in the Consumption plan. To run on Linux, you should
  instead use the Flex Consumption plan."*

So the "preview" wording is stale docs lag. Note the spike **cannot** prove this:
it only shows .NET 10 builds, runs, and debugs *locally*. Service-side support tier
is a docs question, and the docs above answer it.

**The real work constraint is the hosting plan, not the .NET version** — and it's
sharper than a version cap: **the Consumption plan is now legacy, and Linux
Consumption is retired outright**
([hosting options](https://learn.microsoft.com/azure/azure-functions/functions-scale)).
.NET 10 is unavailable there (footnote 5). A work app on Linux Consumption is on a
dead plan and needs migrating to Flex Consumption regardless of framework; the
.NET choice follows that migration, not the other way round.

## 5b. Hosting plans

| Plan | Status | OS | Scale to zero | Max instances | VNet | Cold start | Billing |
|---|---|---|---|---|---|---|---|
| **Flex Consumption** | GA — **default for new** | Linux only | ✅ | 1,000 | ✅ | mitigated via optional always-ready | executions + active memory + always-ready |
| **Premium** (Elastic Premium) | GA | Win + Linux | ❌ (min 1 warm) | Win 100 / Linux 20–100 | ✅ | none (prewarmed) | core-seconds + memory; most predictable |
| **Dedicated** (App Service) | GA | Win + Linux | ❌ | 10–30 (100 ASE) | ✅ | none with Always On | same as App Service; free if reusing spare capacity |
| **Container Apps** | GA | Linux | ✅ (min replicas 0) | 300–1,000 | ✅ | depends on min replicas | Container Apps billing |
| **Consumption** | **legacy**; Linux **retired** | Windows only | ✅ | Win 200 | ❌ | yes | executions + time + memory |

Picking, in short:

- **Flex Consumption** — the default. Serverless pay-per-use *and* VNet *and* fast
  scale, which old Consumption couldn't combine. Cost: Linux only.
- **Premium** — when you need no cold starts at all, run near-continuously, need
  >Consumption's execution timeout, or need Windows *with* VNet.
- **Dedicated** — when you already own an App Service plan with spare capacity
  (effectively free marginal cost), or need ASE isolation. You give up event-driven
  scale.
- **Container Apps** — when the rest of the estate is already containers/K8s-shaped.
- **Consumption** — legacy. Don't start here; migrate off it.

**Windows vs Linux:** Linux is the strategic direction (Flex is Linux-only) and is
generally cheaper. Choose Windows only for a hard Windows dependency (e.g. .NET
Framework 4.8 isolated) — note VS *remote* debugging of C# is Windows-only too,
though that's irrelevant to this Neovim workflow.

## 6. Core Tools v4 vs the "Azure Functions CLI" — yes, it's v5

They are two different tools shipping the *same binary name* (`func.exe`):

| | Core Tools | Azure Functions CLI |
|---|---|---|
| version | **v4** (yours, 4.12.1) | **v5** |
| support | **GA** | **Preview** |
| install | one full binary, all languages | small base + per-language *workloads* |

v5 is "the next major version of the local development runtime and tooling"
([docs](https://learn.microsoft.com/azure/azure-functions/functions-cli-develop-local)).
What's new: a workload model (`func setup --features dotnet`, `func workload
install`) so you only download your stack; the host ships as its own workload, so
you get host updates without re-downloading the CLI; plus quickstart templates and
"profiles" that keep your local environment in sync with your Azure hosting-plan
config.

**Stay on v4.** It's GA, it's what's installed, and v5 doesn't support PowerShell
or Java yet — relevant given `powershell_es` is already wired here.

## 7. Plugins — all skipped

| Plugin | Maintained? | Verdict |
|---|---|---|
| `nvim-dap-cs` | no — last push 2025-01 | **skip** — wraps ~10 lines of adapter boilerplate |
| `azfunc.nvim` | marginal — 1 substantive commit, 6 stars | **skip** — finds the worker with `pgrep`, which doesn't exist on Windows |
| `easy-dotnet.nvim` | — | **skip** — `<leader>nt/nr/nb` in `after/ftplugin/cs.lua` already shell out to `dotnet` |

## Open questions

1. **`nvim-dap` is declared but not installed here.** It's in `plugins.lua` and
   pinned in the lockfile, yet absent from `nvim-data/site/pack/core/opt` — the
   only declared plugin missing. So the existing PowerShell/PSES debugging setup
   presumably isn't functional on this machine either. Worth understanding before
   adding a second DAP consumer. (The spike cloned nvim-dap at the pinned rev into
   scratch rather than touching your real data dir.)
2. **Adopt or not?** If yes: add `Samsung.NetCoreDbg` to `winget/packages.json`,
   add the `dap.lua` block, and decide where Azurite's lifecycle lives (manual per
   session vs. a background service).
3. **Which hosting plan do the work apps use?** That, not the .NET version, decides
   whether net10.0 is available (Linux Consumption caps at .NET 9).
4. **Keymaps.** `after/ftplugin/cs.lua` has no DAP maps; `ps1.lua` has the
   `<F5>`/`<leader>b` set. Mirror them for `cs` if we adopt.
