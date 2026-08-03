# Azure CLI named-profile isolation

## Status

Accepted. This ADR preserves the rejected alternatives and verified experiments behind
the `azs` storage and discovery design. Current behavior remains documented in
[`powershell/README.md`](../../powershell/README.md) and implemented in
[`powershell/Profile/AzCliAccount.ps1`](../../powershell/Profile/AzCliAccount.ps1).

## Context

Azure CLI stores account, subscription, extension, and token-cache state beneath one
configuration directory. The profile switch must isolate CLI identities without also
switching Azure PowerShell state, must tolerate files held open by `az`, and must not
treat unrelated Azure tooling directories as profiles.

## Decision

Each named profile is a self-contained directory under `~/.azure-profiles/`, selected
through `AZURE_CONFIG_DIR`. The directories are the only profile registry. The reserved
`default` profile unsets `AZURE_CONFIG_DIR` and leaves `~/.azure` untouched.

## Rejected alternatives

### Retarget `~/.azure` with a junction or symlink

Retargeting a reparse point is one metadata write and succeeds while files beneath the
target are open. It was mechanically the strongest switching option, but on Windows
`~/.azure` is one case-insensitive directory shared by Azure CLI and Azure PowerShell:
`AzureRmContext.json` sits beside `azureProfile.json`. Retargeting it would silently
switch every `Get-Az*` command too, so `~/.azure` must remain untouched.

### Swap profile directories

PowerShell `Move-Item` performs a copy followed by deletion for this case rather than an
atomic directory rename. A failed experiment left torn state: the destination was
emptied while the source still retained the payload. `[IO.Directory]::Move` is atomic
but fails while any contained file is open, and `az` holds `msal_token_cache.bin` open
during commands. Directory swapping would also make the selected CLI identity mutable
machine-global state rather than shell-local state.

### Discover profiles with a `~/.azure-*` glob

The home directory already contains unrelated directories such as `.azure-devops`,
`.azure-functions-core-tools`, and `.azurefunctions`. A glob would offer these as login
profiles. A dedicated `~/.azure-profiles/` container gives discovery an unambiguous
boundary.

### Keep a profile manifest

A manifest would duplicate the directories that actually hold credentials and could
drift from them. Directory presence is therefore the only registry: adding a profile
means switching to its directory and logging in, never editing a second inventory.
