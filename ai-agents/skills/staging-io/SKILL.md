---
name: staging-io
description: "Use when handing a PowerShell script or manual steps to the work PC (WPC) via the plain-text staging folder at E:\\HollardInsuranceRetail\\staging\\, or when reading back what the engineer pasted from the WPC. Covers writing to to-wpc\\, reading replies from from-wpc\\, naming and header conventions, redaction guardrails, and the close-out archive triage. Does not fire for unrelated PowerShell authoring that never crosses the staging folder."
metadata:
  author: justin
  version: "1.0.0"
---

# Staging folder I/O (WPC hand-carry)

Drives the plain-text hand-carry lanes at `E:\HollardInsuranceRetail\staging\` between this
device (Conditional Access blocks Azure DevOps here) and the work PC (WPC). This is prose
instructions only — there is no wrapper script, CLI, or module, and none should be added; the
staging folder itself stays a dumb folder with no daemon or sync.

Fixed root: `E:\HollardInsuranceRetail\staging\`
- `to-wpc\` — outbound lane. This skill writes scripts and prose steps here.
- `from-wpc\` — inbound lane. The engineer pastes WPC output or error text here.
- `done\<YYYY-MM-DD>\to-wpc\` and `done\<YYYY-MM-DD>\from-wpc\` — archive, split by lane, date
  is the day of the move.
- `README.txt` and `INBOUND-SAFETY.txt` at the root are the full contract. Read them if any
  rule below is unclear or contested — this skill mirrors them, it does not supersede them.

## Writing outbound (to-wpc\)

Name: `<ticket>-<seq>-<slug>.<ext>` — no reply suffix on outbound files.

- `ticket` — the ADO work-item number (digits), or the literal `adhoc`.
- `seq` — two digits, `01`-`99`, unique per ticket across the *whole* staging tree: scan both
  `to-wpc\<ticket>-*` and every `done\*\to-wpc\<ticket>-*`, take the highest existing seq for
  that ticket, and use the next one. A closed-and-archived seq is never reissued.
- `slug` — lowercase words joined by `-`, describing the action.
- `ext` — `.ps1` script, `.txt` prose/output, `.json` or `.csv` data.
- A changed script for the same ticket gets a new `seq`, never a `retryNN` (that suffix is
  inbound-only, see below).

Every outbound `.ps1`, and every prose `.txt` of manual steps, opens with exactly these four
lines:

```
# <what this script does, one or two lines>
# Run on: WPC from <absolute WPC path> on branch <name>
# Paste output into: <exact from-wpc path, matching this file's ticket and seq>
# Needs: az login done; no secrets in this file
```

The WPC path in `Run on:` is the work PC's own path and is never assumed to match the personal
device path — ask the engineer or use a path they confirmed. The `Paste output into:` path
carries this file's own ticket and seq with a reply suffix (`-out.txt` is the default
expectation; the engineer will use `-err` or `-retryNN` as the outcome demands).

Worked example — writing `to-wpc\814107-01-create-three-prs.ps1`, next free seq for ticket
`814107` being `01`:

```
# Creates three feature-branch PRs from the open work items in this sprint.
# Run on: WPC from C:\Repos\HollardInsuranceRetail\api on branch feature/sprint-42
# Paste output into: from-wpc\814107-01-create-three-prs-out.txt
# Needs: az login done; no secrets in this file
```

`814107-01-create-three-prs.ps1` matches `^(\d+|adhoc)-\d{2}-[a-z0-9-]+\.[a-z0-9]+$`, and the
`Paste output into:` line's ticket (`814107`) and seq (`01`) match the file's own name.

WPC encoding gotchas — the file this skill writes must already be UTF-8 without BOM, LF line
endings, and straight ASCII quotes (no smart quotes); a BOM, CRLF, or smart quote can break a
`.ps1` on the WPC with an unrelated-looking error. Tell the engineer to save from Notepad using
the "All files (*.*)" type filter, or Notepad appends `.txt` and silently saves `script.ps1` as
`script.ps1.txt`.

## Reading inbound (from-wpc\)

Name: `<ticket>-<seq>-<slug>-<reply>.<ext>` — reply suffix is mandatory.

Pair a reply to its outbound file by matching `ticket` and `seq` in the opposite lane. The slug
is for humans only and is never used for pairing.

- `out` — the command ran; this is its output.
- `err` — the command failed; this is the error text.
- `retryNN` (`NN` two digits from `01`) — the same outbound script was re-run as-is. A re-run
  with a changed script is a new outbound file with a new seq, not a retry.

When asked to read back a WPC result, locate the `from-wpc\<ticket>-<seq>-*` file(s), report
which reply kind arrived, and treat `err`/late `retryNN` chains as signalling the outbound
script needs a fix (new seq) rather than another retry of the same script.

## Redaction guardrails

Outbound (this skill's own writes): never put a live secret value in a `to-wpc\` file. Refer to
secrets by name only — Key Vault name and secret name, service connection name, variable group
name — never the value. Assume `az login` is already done on the WPC; never write commands that
print or export credentials.

Inbound: the engineer redacts before pasting into `from-wpc\`. Point them at
`E:\HollardInsuranceRetail\staging\INBOUND-SAFETY.txt` for the full rules rather than repeating
them here. If a secret lands in `from-wpc\` anyway, the file gets deleted and the secret
rotated — it is never edited to strip the secret and kept.

## Close-out triage (on PBI -> Done)

Live lanes hold open-ticket files only. The close trigger is the ADO PBI moving to **Done**.

On close, walk every `<ticket>-*` file across both lanes with the engineer and decide **per
file**, one at a time — never a bulk move:
- delete
- archive to `done\<YYYY-MM-DD>\`, keeping the `to-wpc\`/`from-wpc\` split, where the date is
  the day of the move (never the file's mtime — a copy between machines resets it)
- promote to the brain repo
- promote to the llmwiki
- something else, as the engineer directs

An `adhoc-*` file archives on the day it stops being useful, following the same per-file
decision. `done\<date>\` folders are purged manually as a whole after 30 days — no automated
purge.
