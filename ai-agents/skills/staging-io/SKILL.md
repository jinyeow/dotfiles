---
name: staging-io
description: "Use when handing a script, command, or manual steps to the work PC (WPC) via the plain-text staging folder at E:\\HollardInsuranceRetail\\staging\\, or when reading back any file the engineer pasted from the WPC. Covers writing to agent-outputs\\, reading replies from agent-inputs\\, the initiative-subfolder layout, naming and header conventions, redaction guardrails, and the close-out archive triage. Does not fire for work that never crosses the staging folder."
metadata:
  author: justin
  version: "1.1.0"
---

# Staging folder I/O (WPC hand-carry)

Drives the plain-text hand-carry lanes at `E:\HollardInsuranceRetail\staging\` between this
device (Conditional Access blocks Azure DevOps here) and the work PC (WPC). This is prose
instructions only. There is no wrapper script, CLI, or module, and none should be added; the
staging folder itself stays a dumb folder with no daemon or sync.

Fixed root: `E:\HollardInsuranceRetail\staging\`
- `agent-outputs\` is the agent's outputs. This skill writes scripts and prose steps here.
- `agent-inputs\` is the agent's inputs. The engineer pastes WPC output or error text here.
- `done\<YYYY-MM-DD>\agent-outputs\` and `done\<YYYY-MM-DD>\agent-inputs\` are the archive,
  split by lane, date is the day of the move.
- `README.txt` and `INBOUND-SAFETY.txt` at the root are the full contract. Read them if any
  rule below is unclear or contested; this skill mirrors them, it does not supersede them.

Both lanes group every file under a mandatory initiative subfolder:
`agent-outputs\<initiative>\<file>` and `agent-inputs\<initiative>\<file>`. `<initiative>` is a
lowercase-hyphen slug you choose (for example `sprint-42-migration`, or `814107-create-prs` for
a single item). One-off checks live under the literal `adhoc`.

## Writing outputs (agent-outputs\)

Name: `<ticket>-<seq>-<slug>.<ext>` with no reply suffix on output files.

- `ticket` is the ADO work-item number (digits), or the literal `adhoc`.
- `seq` is two digits, `01`-`99`, unique per ticket across the *whole* staging tree. Scan for
  that ticket in both lanes and both archives (`agent-outputs\*\<ticket>-*`,
  `agent-inputs\*\<ticket>-*`, `done\*\agent-outputs\*\<ticket>-*`,
  `done\*\agent-inputs\*\<ticket>-*`), take the highest existing seq, and use the next one. A
  closed-and-archived seq is never reissued, so scanning the input archive too prevents handing
  out a seq whose reply was archived after its output file was deleted.
- `slug` is lowercase words joined by `-`, describing the action.
- `ext` is any suitable extension: `ps1`, `txt`, `md`, `json`, `jsonc`, `csv`, and so on.
- A changed script for the same ticket gets a new `seq`, never a `retryNN` (that suffix is
  input-only, see below).

Every output `.ps1`, and every prose `.txt` of manual steps, opens with these four fields (the
first may wrap to a second line):

```
# <what this script does, one or two lines>
# Run on: WPC from <absolute WPC path> on branch <name>
# Paste output into: <exact agent-inputs path, matching this file's initiative, ticket, and seq>
# Needs: az login done; no secrets in this file
```

The WPC path in `Run on:` is the work PC's own path and is never assumed to match the personal
device path. Ask the engineer or use a path they confirmed. The `Paste output into:` path
carries this file's own initiative, ticket, and seq with a reply suffix (`-out.txt` is the
default expectation; the engineer uses `-err` or `-retryNN` as the outcome demands).

Worked example, writing `agent-outputs\sprint-42\814107-01-create-three-prs.ps1`, next free seq
for ticket `814107` being `01`:

```
# Creates three feature-branch PRs from the open work items in this sprint.
# Run on: WPC from C:\Repos\HollardInsuranceRetail\api on branch feature/sprint-42
# Paste output into: agent-inputs\sprint-42\814107-01-create-three-prs-out.txt
# Needs: az login done; no secrets in this file
```

`814107-01-create-three-prs.ps1` matches `^(\d+|adhoc)-\d{2}-[a-z0-9-]+\.[a-z0-9]+$`, and the
`Paste output into:` line's initiative (`sprint-42`), ticket (`814107`), and seq (`01`) match
the file's own path and name.

WPC encoding gotchas: the file this skill writes must already be UTF-8 without BOM, LF line
endings, and straight ASCII quotes (no smart quotes). A BOM, CRLF, or smart quote can break a
`.ps1` on the WPC with an unrelated-looking error. Tell the engineer to save from Notepad using
the "All files (*.*)" type filter, or Notepad appends `.txt` and silently saves `script.ps1` as
`script.ps1.txt`.

## Reading inputs (agent-inputs\)

Name: `<ticket>-<seq>-<slug>-<reply>.<ext>`, reply suffix mandatory.

Pair a reply to its output file by matching `initiative`, `ticket`, and `seq` in the opposite
lane. The slug is for humans only and is never used for pairing.

- `out` means the command ran; this is its output.
- `err` means the command failed; this is the error text.
- `retryNN` (`NN` two digits from `01`) means the same output file was re-run as-is.

When asked to read back a WPC result, locate the `agent-inputs\<initiative>\<ticket>-<seq>-*`
file(s) and report which reply kind arrived. On an `err`, decide the cause before reacting:
- If the script itself is wrong (bug, bad parameter, wrong path), fix it and write a new output
  file with a new `seq`.
- If the script is fine and the environment failed (expired `az login`, transient network, WPC
  not ready), the same unchanged script can be re-run as a `retryNN`, not a new seq.

## Redaction guardrails

Outputs (this skill's own writes): never put a live secret value in an `agent-outputs\` file.
Refer to secrets by name only (Key Vault name and secret name, service connection name,
variable group name), never the value. Assume `az login` is already done on the WPC; never write
commands that print or export credentials.

Inputs: the engineer redacts before pasting into `agent-inputs\`. Point them at
`E:\HollardInsuranceRetail\staging\INBOUND-SAFETY.txt` for the full rules rather than repeating
them here. If a secret lands in `agent-inputs\` anyway, the file gets deleted and the secret
rotated. It is never edited to strip the secret and kept.

## Close-out triage (on PBI -> Done)

Live lanes hold open-ticket files only. The close trigger is the ADO PBI moving to **Done**.

On close, walk every `<ticket>-*` file across both lanes with the engineer and decide **per
file**, one at a time, never a bulk move:
- delete
- archive to `done\<YYYY-MM-DD>\`, keeping the `agent-outputs\`/`agent-inputs\` lane split and
  the initiative subfolder, where the date is the day of the move (never the file's mtime, a
  copy between machines resets it)
- promote to the brain repo
- promote to the llmwiki
- something else, as the engineer directs

An `adhoc-*` file archives on the day it stops being useful, following the same per-file
decision. `done\<date>\` folders are purged manually as a whole after 30 days, no automated
purge.
